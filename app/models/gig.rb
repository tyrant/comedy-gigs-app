class Gig < ApplicationRecord
  include Sourced

  # Relationships
  belongs_to :venue
  has_and_belongs_to_many :acts

  # Validations
  validates :name, :start_time, presence: true
  validates :status, inclusion: { in: %w[scheduled cancelled postponed sold_out] }
  validate :end_time_after_start_time, if: -> { start_time.present? && end_time.present? }

  before_save :set_local_date, if: -> { local_date.nil? || start_time_changed? || venue_id_changed? }

  scope :between,        ->(start_date, end_date) { where(start_time: start_date..end_date) }
  scope :by_status,      ->(status)               { where(status: status) }
  scope :featuring_act,  ->(act_id)               { joins(:acts).where(acts: { id: act_id }) }

  # EXISTS rather than plucking matching IDs first: one query, no unbounded IN list
  scope :featuring_acts, ->(act_ids) {
    return all if act_ids.blank?

    where("EXISTS (SELECT 1 FROM acts_gigs WHERE acts_gigs.gig_id = gigs.id AND acts_gigs.act_id IN (?))", act_ids)
  }

  # Dates are the venue's own calendar dates: "today" in Auckland starts 13
  # hours before it does in London. local_date holds each gig's.
  scope :starting_after, ->(start_date) {
    parsed_date = Gig.send(:parse_date, start_date)
    parsed_date ? where(local_date: parsed_date..) : all
  }

  scope :starting_before, ->(end_date) {
    parsed_date = Gig.send(:parse_date, end_date)
    parsed_date ? where(local_date: ..parsed_date) : all
  }

  # How long a gig with no end time is taken to run
  ASSUMED_LENGTH = 2.hours

  # Gigs still to finish. One with no end time counts as over ASSUMED_LENGTH
  # after it starts, plus an hour's grace for late starts and long sets.
  scope :not_over, ->(now = Time.current) {
    where("gigs.end_time >= :now OR (gigs.end_time IS NULL AND gigs.start_time >= :started)",
          now:, started: now - ASSUMED_LENGTH - 1.hour)
  }

  # The filters the map's API endpoints share: start_date, end_date, act_ids
  # (comma-separated) and upcoming (leave out gigs already over). Cancelled
  # gigs are never shown. "Now" is rounded down to the quarter-hour, so the
  # query, and so the API's cache keys, hold still in between.
  def self.filtered_for_api(params = {})
    scope = where.not(status: "cancelled")
    scope = scope.not_over(Time.zone.at(Time.current.to_i / 15.minutes * 15.minutes)) if params[:upcoming].present?
    scope = scope.featuring_acts(params[:act_ids].to_s.split(",").map(&:to_i).select(&:positive?))
    scope = scope.starting_after(params[:start_date])
    scope.starting_before(params[:end_date])
  end
  # The start's date where the gig happens; venues with no (known) time zone count as UTC
  def set_local_date
    zone = ActiveSupport::TimeZone[venue&.timezone.to_s] || ActiveSupport::TimeZone["UTC"]
    self.local_date = start_time&.in_time_zone(zone)&.to_date
  end

  private

  def end_time_after_start_time
    return unless end_time < start_time

    errors.add(:end_time, "must be after start time")
  end

  class << self
    private

    def parse_date(date_string)
      return nil if date_string.blank?
      Date.parse(date_string)
    rescue ArgumentError
      nil
    end
  end
end

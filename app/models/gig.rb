class Gig < ApplicationRecord
  # Relationships
  belongs_to :venue
  has_and_belongs_to_many :acts

  # Validations
  validates :name, :start_time, presence: true
  validates :status, inclusion: { in: %w[scheduled cancelled postponed sold_out] }
  validate :end_time_after_start_time, if: -> { start_time.present? && end_time.present? }

  attribute :external_ids, :jsonb, default: -> { {} }

  before_save :set_local_date, if: -> { local_date.nil? || start_time_changed? || venue_id_changed? }

  scope :between,        ->(start_date, end_date) { where(start_time: start_date..end_date) }
  scope :by_status,      ->(status)               { where(status: status) }
  scope :by_external_id, ->(source, id)           { where("external_ids @> ?", { source => id.to_s }.to_json) }
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

  # The filters the map's API endpoints share: start_date, end_date and act_ids
  # (comma-separated). Cancelled gigs are never shown.
  def self.filtered_for_api(params = {})
    scope = where.not(status: "cancelled")
    scope = scope.featuring_acts(params[:act_ids].to_s.split(",").map(&:to_i).select(&:positive?))
    scope = scope.starting_after(params[:start_date])
    scope.starting_before(params[:end_date])
  end

  def self.from_existing(data, source)
    gig = Gig.by_external_id(source, data[:external_ids][source]).first
    return gig if gig

    return nil unless data[:name].present? && data[:start_time].present?

    # The same show from another source: same name, about the same time, and
    # (when known) the same venue, so two "Comedy Night"s in different towns stay apart
    matches = Gig.where("LOWER(name) = ?", data[:name].downcase)
      .where(start_time: (data[:start_time] - 1.hour)..(data[:start_time] + 1.hour))
    matches = matches.where(venue: data[:venue]) if data[:venue]
    matches.first
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

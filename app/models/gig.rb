class Gig < ApplicationRecord
  # Relationships
  belongs_to :venue
  has_and_belongs_to_many :acts

  # Validations
  validates :name, :start_time, presence: true
  validates :status, inclusion: { in: %w[scheduled cancelled postponed sold_out] }
  validate :end_time_after_start_time, if: -> { start_time.present? && end_time.present? }

  attribute :external_ids, :jsonb, default: -> { {} }

  scope :between,        ->(start_date, end_date) { where(start_time: start_date..end_date) }
  scope :by_status,      ->(status)               { where(status: status) }
  scope :by_external_id, ->(source, id)           { where("external_ids->>'#{source}' = ?", id.to_s) }
  scope :featuring_act,  ->(act_id)               { joins(:acts).where(acts: { id: act_id }) }
  scope :within_bounds,  ->(bounds)               { joins(:venue).merge(Venue.within_bounding_box(bounds)) }

  scope :featuring_acts, ->(act_ids) {
    return all if act_ids.blank?

    gig_ids_with_acts = joins(:acts).where(acts: { id: act_ids }).distinct.pluck(:id)
    where(id: gig_ids_with_acts)
  }

  scope :starting_after, ->(start_date) {
    return all if start_date.blank?

    parsed_date = Gig.send(:parse_date, start_date)
    return all unless parsed_date

    where("start_time >= ?", parsed_date.beginning_of_day)
  }

  scope :starting_before, ->(end_date) {
    return all if end_date.blank?

    parsed_date = Gig.send(:parse_date, end_date)
    return all unless parsed_date

    where("start_time <= ?", parsed_date.end_of_day)
  }

  def self.filtered_for_api(params = {})
    scope = includes(:venue, :acts)

    if bounds_params_present?(params)
      sw = [ params[:south].to_f, params[:west].to_f ]
      ne = [ params[:north].to_f, params[:east].to_f ]
      scope = scope.within_bounds([ sw, ne ])
    end

    if params[:act_ids].present?
      act_ids = params[:act_ids].split(",")
      scope = scope.featuring_acts(act_ids)
    end

    scope = scope.starting_after(params[:start_date])
    scope = scope.starting_before(params[:end_date])

    scope.order(:id)
  end

  def self.serialize_for_api(gigs)
    gigs.map do |gig|
      gig_json = gig.as_json
      gig_json["venue"] = gig.venue.as_json(methods: [ :latitude, :longitude, :primary_image_url ])
      gig_json["acts"] = gig.acts.map { |act| act.as_json(methods: [ :primary_image_url ]) }
      gig_json
    end
  end

  private

  def end_time_after_start_time
    return unless end_time < start_time

    errors.add(:end_time, "must be after start time")
  end

  class << self
    private

    def bounds_params_present?(params)
      params[:north].present? && params[:south].present? &&
      params[:east].present? && params[:west].present?
    end

    def parse_date(date_string)
      return nil if date_string.nil?
      Date.parse(date_string)
    rescue ArgumentError
      nil
    end
  end
end

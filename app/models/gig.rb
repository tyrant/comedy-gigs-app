class Gig < ApplicationRecord
  # Relationships
  belongs_to :venue
  has_and_belongs_to_many :acts

  # Validations
  validates :name, :start_time, presence: true
  validates :status, inclusion: { in: %w[scheduled cancelled postponed sold_out] }
  validate :end_time_after_start_time, if: -> { start_time.present? && end_time.present? }

  # Ensure external_ids is always a hash
  attribute :external_ids, :jsonb, default: -> { {} }

  # Scopes
  scope :upcoming, -> { where("start_time > ?", Time.current).order(:start_time) }
  scope :past, -> { where("start_time <= ?", Time.current).order(start_time: :desc) }

  scope :between, ->(start_date, end_date) {
    where(start_time: start_date..end_date)
  }

  scope :by_status, ->(status) { where(status: status) }

  scope :by_external_id, ->(source, id) {
    where("external_ids->>'#{source}' = ?", id.to_s)
  }

  scope :featuring_act, ->(act_id) {
    joins(:acts).where(acts: { id: act_id })
  }

  private

  def end_time_after_start_time
    return unless end_time < start_time

    errors.add(:end_time, "must be after start time")
  end
end

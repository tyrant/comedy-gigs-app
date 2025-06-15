class Act < ApplicationRecord
  # Relationships
  has_and_belongs_to_many :gigs

  # Validations
  validates :name, presence: true
  
  # Ensure social_links and external_ids are always hashes
  attribute :social_links, :jsonb, default: -> { {} }
  attribute :external_ids, :jsonb, default: -> { {} }

  # Scopes
  scope :performing_between, ->(start_date, end_date) {
    joins(:gigs).where(gigs: { start_time: start_date..end_date }).distinct
  }

  scope :by_external_id, ->(source, id) {
    where("external_ids->>'#{source}' = ?", id.to_s)
  }
end

class Act < ApplicationRecord
  # Remove the ActionView helper as it won't work properly in API contexts

  # Relationships
  has_and_belongs_to_many :gigs

  # Validations
  validates :name, presence: true

  # Ensure social_links, external_ids, and images are always hashes
  attribute :social_links, :jsonb, default: -> { {} }
  attribute :external_ids, :jsonb, default: -> { {} }
  attribute :images, :jsonb, default: -> { {} }

  # Scopes
  scope :performing_between, ->(start_date, end_date) {
    joins(:gigs)
      .where("gigs.start_time >= ? AND gigs.start_time <= ?",
             start_date.beginning_of_day,
             end_date.end_of_day)
      .distinct
  }

  scope :by_external_id, ->(source, id) {
    where("external_ids->>'#{source}' = ?", id.to_s)
  }

  # Use a placeholder image that will definitely work
  # For production, you should use your own hosted image
  IMAGE_PLACEHOLDER = "/images/comedian_placeholder.png"

  # Helper method to get the primary image URL
  def primary_image_url(size = "standard")
    return IMAGE_PLACEHOLDER if images.blank?

    # Try to find an image with the requested size
    if images[size].present?
      images[size]
    # Fall back to the first available size
    elsif images.values.first.present?
      images.values.first
    else
      IMAGE_PLACEHOLDER
    end
  end
end

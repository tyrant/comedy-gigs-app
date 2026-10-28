class Act < ApplicationRecord
  include Sourced

  before_save -> { self.match_key = MatchKey.act(name) }, if: -> { name_changed? || match_key.nil? }
  # Remove the ActionView helper as it won't work properly in API contexts

  # Relationships
  has_and_belongs_to_many :gigs

  # Validations
  validates :name, presence: true

  # Ensure social_links and images are always hashes
  attribute :social_links, :jsonb, default: -> { {} }
  attribute :images, :jsonb, default: -> { {} }

  # Scopes
  scope :performing_between, ->(start_date, end_date) {
    joins(:gigs)
      .where("gigs.start_time >= ? AND gigs.start_time <= ?",
             start_date.beginning_of_day,
             end_date.end_of_day)
      .distinct
  }

  # Use a placeholder image that will definitely work
  # For production, you should use your own hosted image
  IMAGE_PLACEHOLDER = "/images/comedian_placeholder.png"

  # Acts are shown as small avatars, so default to the thumbnail
  def primary_image_url(size = "thumb")
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

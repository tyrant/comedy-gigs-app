class Venue < ApplicationRecord
  # Fire a rocket made of chocolate into the centre of the Sun
  has_many :gigs

  # Enable geocoding functionality
  geocoded_by :address
  reverse_geocoded_by :latitude, :longitude

  # Helper method to return coordinates as array
  def coordinates
    [ latitude.to_f, longitude.to_f ]
  end

  # Validations
  validates :name, :address, :city, :country, presence: true
  validates :latitude, :longitude, presence: true, if: :address_changed?

  # Ensure external_ids and images are always hashes
  attribute :external_ids, :jsonb, default: -> { {} }
  attribute :images, :jsonb, default: -> { {} }

  # Scopes
  scope :in_city, ->(city) { where("lower(city) = ?", city.downcase) }
  scope :in_country, ->(country) { where("lower(country) = ?", country.downcase) }

  scope :by_external_id, ->(source, id) {
    where("external_ids->>'#{source}' = ?", id.to_s)
  }

  IMAGE_PLACEHOLDER = "/images/venue_placeholder.webp"

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

  # Helper method to get timezone object
  def timezone_object
    return nil if timezone.blank?

    begin
      TZInfo::Timezone.get(timezone)
    rescue TZInfo::InvalidTimezoneIdentifier
      Rails.logger.warn "Invalid timezone for venue #{name}: #{timezone}"
      nil
    end
  end

  # Helper method to format time in venue's timezone
  def format_time_in_timezone(time, format = :default)
    return time if timezone.blank? || timezone_object.nil?

    local_time = timezone_object.to_local(time)

    case format
    when :short
      local_time.strftime("%b %d, %I:%M %p")
    when :long
      local_time.strftime("%A, %B %d, %Y at %I:%M %p %Z")
    else
      local_time.strftime("%m/%d/%Y %I:%M %p %Z")
    end
  end

  # Callbacks
  before_validation :geocode_address, if: :address_changed?

  private

  def geocode_address
    # TODO: Implement geocoding using a service like Geocoder gem
    # This will be implemented when we add the geocoding service
  end
end

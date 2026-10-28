class Venue < ApplicationRecord
  include Sourced

  # Fire a rocket made of chocolate into the centre of the Sun
  has_many :gigs

  before_save -> { self.match_key = MatchKey.venue(name, city) }, if: -> { name_changed? || city_changed? || match_key.nil? }

  # Gigs keep their date on this venue's calendar; a new time zone can move it
  after_update_commit :redate_gigs, if: :saved_change_to_timezone?

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

  # Ensure images is always a hash
  attribute :images, :jsonb, default: -> { {} }

  # Scopes
  scope :in_city, ->(city) { where("lower(city) = ?", city.downcase) }
  scope :in_country, ->(country) { where("lower(country) = ?", country.downcase) }

  IMAGE_PLACEHOLDER = "/images/venue_placeholder.webp"

  # Venues are shown as ~330px popup headers, which "medium" (~640px) suits
  def primary_image_url(size = "medium")
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

  def redate_gigs
    gigs.find_each do |gig|
      gig.set_local_date
      gig.update_column(:local_date, gig.local_date)
    end
  end
end

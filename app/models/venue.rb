class Venue < ApplicationRecord
  # Relationships
  has_many :gigs

  # Validations
  validates :name, :address, :city, :country, presence: true
  validates :latitude, :longitude, presence: true, if: :address_changed?
  
  # Ensure external_ids is always a hash
  attribute :external_ids, :jsonb, default: -> { {} }

  # Scopes
  scope :in_city, ->(city) { where('lower(city) = ?', city.downcase) }
  scope :in_country, ->(country) { where('lower(country) = ?', country.downcase) }
  
  scope :by_external_id, ->(source, id) {
    where("external_ids->>'#{source}' = ?", id.to_s)
  }

  scope :within_bounds, ->(sw_lat, sw_lng, ne_lat, ne_lng) {
    where(latitude: sw_lat..ne_lat, longitude: sw_lng..ne_lng)
  }

  # Callbacks
  before_validation :geocode_address, if: :address_changed?

  private

  def geocode_address
    # TODO: Implement geocoding using a service like Geocoder gem
    # This will be implemented when we add the geocoding service
  end
end

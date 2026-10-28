# Venue lookups go to OpenStreetMap's Nominatim. Its usage policy asks for an
# identifying user agent, at most one request a second (VenueLocator spaces
# them out) and no repeat lookups (found coordinates are kept on the venue).
Geocoder.configure(
  lookup: Rails.env.test? ? :test : :nominatim,
  timeout: 5,
  http_headers: { "User-Agent" => "ComedyGigs/1.0 (+https://sexyverse.email)" }
)

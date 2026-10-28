# Fills in what a source left out of a venue: coordinates looked up from its
# street address or postcode, and a city and country from its coordinates.
#
# It never settles for a city-wide match (a pin in the city centre would send
# people to the wrong door), so a venue it can't place stays unplaced.
class VenueLocator
  # Nominatim's usage policy: no more than one request a second
  RATE_LIMITER = RateLimiter.new("nominatim", max_requests: 1, interval: 1.second)

  # Nominatim ranks results from 30 (a building) to 26 (a street), 21-25 (a
  # postcode) and on down to 16 (a city) and 4 (a country). Anything vaguer
  # than a postcode is too vague to put a pin on.
  MIN_PLACE_RANK = 21

  # How far an address match may be from the venue's postcode
  NEAR_KM = 3

  # data: the venue attributes from a source, plus :postcode and :country_code
  # hints. Returns the attributes with whatever could be found filled in.
  def self.call(data) = new.call(data)

  def initialize
    @cache = {} # query -> result, so one bad address isn't looked up for every gig there
  end

  def call(data)
    data = data.dup
    hints = { postcode: data.delete(:postcode), country_code: data.delete(:country_code) }

    if data[:latitude].blank? || data[:longitude].blank?
      result = place(data, hints)
      data.merge!(latitude: result.latitude, longitude: result.longitude) if result
    end

    if (data[:city].blank? || data[:country].blank?) && data[:latitude].present?
      surroundings = search([ data[:latitude], data[:longitude] ])
      data[:city] = data[:city].presence || surroundings&.city
      data[:country] = data[:country].presence || surroundings&.country
    end

    data
  end

  private

  # The address is checked against the postcode when there is one, since
  # street names recur ("Market Place" is in Malton as well as Pocklington);
  # failing that, the postcode itself is precise enough for a pin, so long as
  # it's in the venue's city (sources get postcodes wrong too). Without a
  # postcode, the match has to name the venue's city.
  def place(data, hints)
    anchor = hints[:postcode].present? && search(hints[:postcode], hints[:country_code])
    anchor = nil unless anchor && precise?(anchor)

    found = address_queries(data, hints).lazy
      .filter_map { |query| search(query, hints[:country_code]) }
      .find { |result| precise?(result) && (anchor ? near?(result, anchor) : in_city?(result, data[:city])) }

    found || (anchor if anchor && in_city?(anchor, data[:city]))
  end

  # Most specific first: the full address, then without its first part
  # ("Unit 6 & 7, 30 Stamford St" -> "30 Stamford St"), then the venue's name
  # (some are listed without an address at all)
  def address_queries(data, hints)
    parts = data[:address].to_s.split(",").map(&:strip).reject(&:blank?)
    locality = [ data[:city], hints[:postcode] ].map(&:presence).compact

    queries = []
    queries << [ *parts, *locality ].join(", ") if parts.any?
    queries << [ *parts.drop(1), *locality ].join(", ") if parts.size > 1
    queries << [ data[:name], data[:city] ].join(", ") if data[:name].present? && data[:city].present?
    queries.uniq
  end

  def near?(result, anchor)
    Geocoder::Calculations.distance_between(result.coordinates, anchor.coordinates, units: :km) <= NEAR_KM
  end

  def precise?(found) = found.data["place_rank"].to_i >= MIN_PLACE_RANK

  # The city as a whole word: "York" in "York, England", not in "Yorkshire"
  def in_city?(found, city)
    return true if city.blank?

    simplify(found.address).match?(/\b#{Regexp.escape(simplify(city))}\b/)
  end

  def simplify(text) = I18n.transliterate(text.to_s).downcase

  def search(query, country_code = nil)
    key = [ query, country_code ]
    return @cache[key] if @cache.key?(key)

    params = country_code.present? ? { countrycodes: country_code.downcase } : {}
    @cache[key] = RATE_LIMITER.with_rate_limit { Geocoder.search(query, params:).first }
  rescue StandardError => e
    Rails.logger.warn "Venue lookup failed for #{query.inspect}: #{e.class}: #{e.message}"
    @cache[key] = nil
  end
end

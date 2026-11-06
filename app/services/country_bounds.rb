# Rough outlines of every country, for catching sources' coordinates that put
# a venue somewhere it can't be. Ticketmaster has placed a Belgian theatre in
# Le Mans, Calgary's Laugh Shop in Nashville, Edinburgh's Monkey Barrel in the
# North Sea (east for west), and others at 0,0 or 1,1.
#
# A country is a few boxes, one around each landmass of each territory its
# state governs (Jersey counts as GB, Puerto Rico as US), padded by PAD and
# joined where they overlap. That's coarse, so it only doubts coordinates well
# outside the country, and VenueLocator then places the venue from its address.
#
# The boxes are built from Natural Earth's admin-0 countries (public domain)
# by `rake country_bounds:build`.
class CountryBounds
  FILE = Rails.root.join("config/country_bounds.json")
  PAD  = 0.5 # degrees, about 55km

  # Whether coordinates are a placeholder (0,0), or outside the country the
  # source says the venue is in. Without a known country, only the placeholder counts.
  def self.misplaced?(latitude, longitude, country_code)
    return false if latitude.blank? || longitude.blank?

    latitude, longitude = latitude.to_f, longitude.to_f
    return true if latitude.zero? && longitude.zero?

    boxes = all[country_code.to_s.upcase]
    boxes.present? && boxes.none? { |south, west, north, east| latitude.between?(south, north) && longitude.between?(west, east) }
  end

  def self.all = @all ||= JSON.parse(File.read(FILE)).freeze

  # Natural Earth GeoJSON features -> { "GB" => [ [ south, west, north, east ], ... ] }
  def self.build(features)
    boxes  = Hash.new { |hash, state| hash[state] = [] }
    states = Hash.new { |hash, code| hash[code] = Set.new }

    features.each do |feature|
      properties, geometry = feature.values_at("properties", "geometry")
      state = properties["SOVEREIGNT"]
      polygons = geometry["type"] == "MultiPolygon" ? geometry["coordinates"] : [ geometry["coordinates"] ]
      polygons.each do |(outline, *_holes)|
        longitudes, latitudes = outline.transpose
        boxes[state] << [ latitudes.min - PAD, longitudes.min - PAD, latitudes.max + PAD, longitudes.max + PAD ]
      end

      code = properties["ISO_A2_EH"] # ISO_A2 is "-99" for France and Norway; this isn't
      states[code] << state unless code == "-99"
    end

    joined = boxes.transform_values { |list| join_overlapping(list) }
    states.sort.to_h { |code, its_states| [ code, its_states.sort.flat_map { |state| joined[state] }.sort ] }
  end

  def self.join_overlapping(boxes)
    loop do
      joined = boxes.each_with_object([]) do |box, kept|
        if (other = kept.find { |kept_box| overlap?(kept_box, box) })
          other.replace([ [ other[0], box[0] ].min, [ other[1], box[1] ].min, [ other[2], box[2] ].max, [ other[3], box[3] ].max ])
        else
          kept << box.dup
        end
      end
      return joined.map { |box| box.map { |degrees| degrees.round(1) } } if joined.size == boxes.size

      boxes = joined
    end
  end

  def self.overlap?(a, b) = a[0] <= b[2] && b[0] <= a[2] && a[1] <= b[3] && b[1] <= a[3]
  private_class_method :join_overlapping, :overlap?
end

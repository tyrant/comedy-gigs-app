require "cgi"

module Api
  # Turns one Eventfinda event into a venue and a gig for each of its sessions.
  #
  # An Eventfinda event is a run of sessions (one night, or a weekly show for
  # months), so each upcoming session becomes its own gig. Times arrive as local
  # wall-clock times with a separate time zone. Events don't name their
  # performers (the API's artists list is empty in practice), so gigs come
  # without acts.
  class EventfindaTransformer
    SOURCE = "eventfinda".freeze
    DEFAULT_TIME_ZONE = "Pacific/Auckland".freeze
    COUNTRY = "New Zealand".freeze

    # Sessions that started this long ago are still worth listing for today
    PAST_GRACE = 6.hours

    # Eventfinda's image transforms; 7 is 650x280, which suits the venue panel
    VENUE_IMAGE_TRANSFORM = 7

    def self.transform_event(event, now: Time.current)
      new(event, now:).call
    end

    def initialize(event, now: Time.current)
      @event = event
      @now = now
    end

    # { venue: {...}, gigs: [ {...}, ... ] }, or nil when the event can't be placed on the map
    def call
      return nil if @event["name"].blank? || location.blank? || coordinates.nil?

      gigs = sessions.filter_map { |session| build_gig(session) }
      return nil if gigs.empty?

      { venue: build_venue, gigs: }
    end

    private

    def location = @event["location"] || {}

    def sessions = @event.dig("sessions", "sessions") || []

    def coordinates
      point = location["point"].presence || @event["point"].presence
      return nil unless point && point["lat"].present? && point["lng"].present?

      [ point["lat"].to_f, point["lng"].to_f ]
    end

    def time_zone_name
      [ @event["timezone"], DEFAULT_TIME_ZONE ].find { |name| ActiveSupport::TimeZone[name.to_s] }
    end

    def build_venue
      latitude, longitude = coordinates

      {
        name: location["name"],
        address: @event["address"].presence || location["summary"],
        city: city,
        country: COUNTRY,
        latitude:,
        longitude:,
        timezone: time_zone_name,
        external_ids: { SOURCE => location["id"].to_s },
        images: venue_images
      }
    end

    # The summary runs from the venue to Eventfinda's region: "Venue, Region"
    # or "Venue, Town, Region". The three big cities are regions of their own,
    # with suburbs before them ("Venue, Kingsland, Auckland").
    CITY_REGIONS = %w[Auckland Wellington Christchurch].freeze

    def city
      parts = location["summary"].to_s.delete_prefix(location["name"].to_s).split(",").map(&:strip).reject(&:blank?)
      return @event["address"].to_s.split(",").map(&:strip).reject(&:blank?).last || location["name"] if parts.empty?

      CITY_REGIONS.include?(parts.last) || parts.size == 1 ? parts.last : parts[-2]
    end

    # Locations without a photo get Eventfinda's stock "sample" image, with no
    # id; better our own placeholder than someone else's stock photo
    def venue_images
      images = location.dig("images", "images") || []
      image = images.find { |img| img["is_primary"] } || images.first
      return {} if image.nil? || image["id"].nil?

      transforms = image.dig("transforms", "transforms") || []
      url = transforms.find { |t| t["transformation_id"] == VENUE_IMAGE_TRANSFORM }&.dig("url") || image["original_url"]
      url.present? ? { "medium" => url } : {}
    end

    def build_gig(session)
      zone = ActiveSupport::TimeZone[session["timezone"].to_s] || ActiveSupport::TimeZone[time_zone_name]
      start_time = parse_time(session["datetime_start"], zone)
      return nil unless start_time && start_time >= @now - PAST_GRACE

      end_time = parse_time(session["datetime_end"], zone)
      end_time = nil unless end_time && end_time > start_time

      {
        name: @event["name"].strip,
        description: plain_text(@event["description"]),
        start_time:,
        end_time:,
        ticket_url: @event["url"], # Eventfinda's terms: listings link to the event's page
        status: status(session),
        external_ids: { SOURCE => session["id"].to_s }
      }
    end

    def status(session)
      return "cancelled" if @event["is_cancelled"] || session["is_cancelled"]
      return "sold_out" if @event["is_sold_out"]

      "scheduled"
    end

    def parse_time(text, zone)
      zone.parse(text.to_s) if text.present?
    rescue ArgumentError
      nil
    end

    def plain_text(html)
      CGI.unescapeHTML(html.to_s.gsub(/<[^>]*>/, " ")).squish
    end
  end
end

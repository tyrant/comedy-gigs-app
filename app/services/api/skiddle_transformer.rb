module Api
  # Turns one Skiddle event into a venue, a gig and the artists it lists.
  #
  # Skiddle's times carry a +00:00 offset all year, but they're UK wall-clock
  # times (a June show at 20:00 comes back as 20:00+00:00, not 19:00+00:00),
  # so the offset is dropped and the time read as London's. Few events list
  # their artists; the importer also looks for known comedians in the title.
  class SkiddleTransformer
    SOURCE = "skiddle".freeze
    TIME_ZONE = "Europe/London".freeze
    COUNTRY = "Great Britain".freeze # as Ticketmaster names it, so venues match

    # Shows that started this long ago are still worth listing for today
    PAST_GRACE = 6.hours

    def self.transform_event(event, now: Time.current)
      new(event, now:).call
    end

    def initialize(event, now: Time.current)
      @event = event
      @now = now
    end

    # { venue: {...}, gig: {...}, acts: [ {...}, ... ] }, or nil when the
    # event can't be placed on the map or is already over
    def call
      return nil if @event["eventname"].blank? || venue["name"].blank? || coordinates.nil?

      start_time = local_time(@event["startdate"])
      return nil unless start_time && start_time >= @now - PAST_GRACE

      { venue: build_venue, gig: build_gig(start_time), acts: build_acts }
    end

    private

    def venue = @event["venue"] || {}

    def zone = ActiveSupport::TimeZone[TIME_ZONE]

    # Skiddle gives 0,0 for a venue it hasn't placed
    def coordinates
      latitude, longitude = venue["latitude"].to_f, venue["longitude"].to_f
      return nil if latitude.zero? && longitude.zero?

      [ latitude, longitude ]
    end

    def build_venue
      latitude, longitude = coordinates

      {
        name: text(venue["name"]),
        address: [ venue["address"], venue["town"], venue["postcode"] ].map { |part| text(part) }.reject(&:blank?).join(", "),
        city: text(venue["town"]).presence,
        country: COUNTRY,
        latitude:,
        longitude:,
        timezone: TIME_ZONE,
        external_ids: { SOURCE => venue["id"].to_s }
      }
    end

    def build_gig(start_time)
      end_time = local_time(@event["enddate"])
      end_time = nil unless end_time && end_time > start_time

      {
        name: text(@event["eventname"]),
        description: text(@event["description"]).presence,
        start_time:,
        end_time:,
        ticket_url: @event["link"], # Skiddle's terms: link to the event's page
        status: @event["cancelled"].to_s == "1" ? "cancelled" : "scheduled",
        external_ids: { SOURCE => @event["id"].to_s }
      }
    end

    def build_acts
      Array(@event["artists"]).select { |artist| artist["name"].present? }.uniq { |artist| artist["artistid"] }.map do |artist|
        {
          name: text(artist["name"]),
          images: artist["image"].present? ? { "large" => artist["image"] } : {},
          social_links: spotify_link(artist["spotifyartisturl"]),
          external_ids: { SOURCE => artist["artistid"].to_s }
        }
      end
    end

    # "spotify:artist:1Vpy38Qac3HJH8YBRFCRhW" -> the artist's open.spotify.com page
    def spotify_link(uri)
      id = uri.to_s[/\Aspotify:artist:(\w+)\z/, 1]
      id ? { "spotify" => "https://open.spotify.com/artist/#{id}" } : {}
    end

    # The wall-clock part of "2027-06-01T20:00:00+00:00", read as London time
    def local_time(text)
      wall_clock = text.to_s[/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?/]
      zone.parse(wall_clock) if wall_clock
    rescue ArgumentError
      nil
    end

    def text(value) = value.to_s.squish
  end
end

module Api
  class TicketmasterTransformer
    def self.transform_event(event_data)
      Rails.logger.debug "Processing event: #{event_data['name']}"

      # Verify this is a comedy event
      unless comedy_event?(event_data)
        Rails.logger.debug "Skipping non-comedy event: #{event_data['name']}"
        return nil
      end

      # Verify we have required data
      unless valid_event?(event_data)
        Rails.logger.debug "Skipping invalid event: #{event_data['name']} - missing required data"
        return nil
      end

      transformed = {
        gig: build_gig(event_data),
        venue: build_venue(event_data.dig("_embedded", "venues", 0)),
        acts: build_acts(event_data.dig("_embedded", "attractions"))
      }

      Rails.logger.debug "Transformed data: #{transformed.inspect}"
      transformed
    end

    private

    def self.comedy_event?(event)
      # Check if event has comedy segment and genre
      classifications = event.dig("classifications") || []
      classifications.any? do |c|
        c.dig("segment", "id") == Api::TicketmasterClient::COMEDY_SEGMENT_ID &&
        c.dig("genre", "id") == Api::TicketmasterClient::COMEDY_GENRE_ID
      end
    end

    def self.valid_event?(event)
      # Check for required fields
      return false unless event["name"].present?
      return false unless event.dig("dates", "start", "dateTime").present?
      return false unless event.dig("_embedded", "venues").present?
      true
    end

    def self.build_gig(event)
      start_time = parse_datetime(event.dig("dates", "start", "dateTime"))
      # If no end time is provided, default to 2 hours after start
      end_time = parse_datetime(event.dig("dates", "end", "dateTime")) || (start_time + 2.hours)

      {
        name: event["name"],
        description: event.dig("description") || "",
        start_time: start_time,
        end_time: end_time,
        ticket_url: event.dig("url"),
        status: map_status(event.dig("dates", "status", "code")),
        external_ids: {
          "ticketmaster" => event["id"]
        }
      }
    end

    def self.build_venue(venue)
      return nil unless venue

      Rails.logger.debug "=== TICKETMASTER VENUE DATA DEBUGGING ==="
      Rails.logger.debug "Venue: #{venue['name']}"
      Rails.logger.debug "Has images? #{venue['images'].present?}"
      if venue["images"].present?
        Rails.logger.debug "Number of venue images: #{venue['images'].size}"
        Rails.logger.debug "First image sample: #{venue['images'].first.inspect}"
      end

      result = {
        # Some Scandinavian venues arrive nameless; the street address is the next best label
        name: venue["name"].presence || venue.dig("address", "line1"),
        # Some venues (often outside the US/UK) come without a street address
        address: venue.dig("address", "line1").presence || venue.dig("city", "name").presence || venue["name"],
        # Some arrive without a city ("London " comes padded); the state is the next best
        city: venue.dig("city", "name").to_s.strip.presence || venue.dig("state", "name"),
        country: venue.dig("country", "name").presence || venue.dig("country", "countryCode"),
        latitude: venue.dig("location", "latitude")&.to_f,
        longitude: venue.dig("location", "longitude")&.to_f,
        description: venue["description"],
        capacity: venue["capacity"]&.to_i,
        timezone: extract_timezone(venue),
        external_ids: {
          "ticketmaster" => venue["id"]
        },
        images: extract_images(venue["images"]),
        website: extract_website(venue),
        # Hints for VenueLocator when the coordinates are missing; not stored
        postcode: venue["postalCode"],
        country_code: venue.dig("country", "countryCode")
      }

      Rails.logger.debug "Final venue images: #{result[:images].inspect}"
      Rails.logger.debug "=== END TICKETMASTER VENUE DATA DEBUGGING ==="

      result
    end

    def self.build_acts(attractions)
      return [] unless attractions

      Rails.logger.debug "=== TICKETMASTER ACTS DATA DEBUGGING ==="
      Rails.logger.debug "Number of attractions: #{attractions.size}"

      # Attractions occasionally arrive nameless, or listed twice on one event
      attractions.select { |act| act["name"].present? }.uniq { |act| act["id"] || act["name"] }.map do |act|
        Rails.logger.debug "Processing act: #{act['name']}"
        Rails.logger.debug "Has images? #{act['images'].present?}"
        if act["images"].present?
          Rails.logger.debug "Number of act images: #{act['images'].size}"
          Rails.logger.debug "First image sample: #{act['images'].first.inspect}"
        end

        act_data = {
          name: act["name"],
          description: act["description"],
          social_links: extract_social_links(act),
          external_ids: {
            "ticketmaster" => act["id"]
          },
          images: extract_images(act["images"])
        }

        Rails.logger.debug "Final act images for #{act['name']}: #{act_data[:images].inspect}"
        act_data
      end.tap do
        Rails.logger.debug "=== END TICKETMASTER ACTS DATA DEBUGGING ==="
      end
    end

    # Ticketmaster has no field for a venue's own website, but its notes
    # often name one ("Visit www.punchlinesac.com"), alongside parking and
    # ticketing sites and link-scanner wrappers. The first other site's home
    # page is the venue's; failing that, its Ticketmaster page.
    NOT_VENUE_SITES = /ticket|livenation|biletix|trendmicro|parking|parkwhiz|parkmobile|q-park|(\A|\.)park[a-z]*\./i

    def self.extract_website(venue)
      notes = venue.values_at("generalInfo", "boxOfficeInfo", "parkingDetail", "accessibleSeatingDetail")
        .flat_map { |info| info.is_a?(Hash) ? info.values : [ info ] }.grep(String).join(" ")
      hosts = notes.scan(%r{\b(?:https?://|www\.)[^\s<>"'),]+}i).filter_map do |url|
        URI.parse(url.match?(%r{\Ahttps?://}i) ? url : "https://#{url}").host&.downcase&.delete_suffix(".")
      rescue URI::InvalidURIError
        nil
      end

      host = hosts.find { |name| name.include?(".") && !name.match?(NOT_VENUE_SITES) }
      host ? "https://#{host}" : venue["url"].to_s[%r{\Ahttps?://\S+}i]
    end

    # The act's own sites, as Ticketmaster gives them (Act#official_links tidies them)
    def self.extract_social_links(act)
      return {} unless act["externalLinks"].is_a?(Hash)

      Act::OFFICIAL_LINK_KINDS.keys.to_h { |kind| [ kind, act.dig("externalLinks", kind, 0, "url") ] }.compact
    end

    def self.parse_datetime(datetime_str)
      datetime_str ? Time.parse(datetime_str) : nil
    end

    def self.map_status(status_code)
      {
        "onsale" => "scheduled",
        "cancelled" => "cancelled",
        "postponed" => "postponed",
        "offsale" => "sold_out"
      }[status_code] || "scheduled"
    end

    def self.extract_timezone(venue)
      # Extract timezone from venue data
      # Ticketmaster API provides timezone in venue.timezone field
      timezone = venue["timezone"]

      # If no timezone is provided, try to infer from location
      if timezone.blank?
        # Fall back to country-based timezone mapping for common countries
        country = venue.dig("country", "name")
        city = venue.dig("city", "name")

        timezone = infer_timezone_from_location(country, city)
      end

      # Validate timezone format (should be IANA timezone identifier)
      if timezone.present? && valid_timezone?(timezone)
        timezone
      else
        Rails.logger.warn "Invalid or missing timezone for venue #{venue['name']}: #{timezone}"
        nil
      end
    end

    def self.infer_timezone_from_location(country, city)
      # Basic timezone inference for common countries
      # This is a fallback when Ticketmaster doesn't provide timezone
      case country&.downcase
      when "united states", "usa", "us"
        # Basic US timezone mapping by city
        case city&.downcase
        when /new york|boston|atlanta|miami|philadelphia|washington/
          "America/New_York"
        when /chicago|dallas|houston|minneapolis|new orleans/
          "America/Chicago"
        when /denver|salt lake city|phoenix|albuquerque/
          "America/Denver"
        when /los angeles|san francisco|seattle|portland|las vegas/
          "America/Los_Angeles"
        else
          "America/New_York" # Default to Eastern
        end
      when "canada"
        case city&.downcase
        when /toronto|montreal|ottawa/
          "America/Toronto"
        when /vancouver|victoria/
          "America/Vancouver"
        when /calgary|edmonton/
          "America/Edmonton"
        else
          "America/Toronto" # Default to Eastern
        end
      when "united kingdom", "uk", "england", "scotland", "wales"
        "Europe/London"
      when "australia"
        case city&.downcase
        when /sydney|melbourne|canberra/
          "Australia/Sydney"
        when /perth/
          "Australia/Perth"
        when /adelaide/
          "Australia/Adelaide"
        when /brisbane/
          "Australia/Brisbane"
        else
          "Australia/Sydney" # Default to Sydney
        end
      when "new zealand"
        "Pacific/Auckland"
      else
        nil # Unknown country, no inference
      end
    end

    def self.valid_timezone?(timezone)
      # Check if timezone is a valid IANA timezone identifier
      return false if timezone.blank?

      begin
        TZInfo::Timezone.get(timezone)
        true
      rescue TZInfo::InvalidTimezoneIdentifier
        false
      end
    end

    # Ticketmaster offers each image at many sizes, from 100px wide up to a
    # multi-megapixel original. Pick the smallest that's big enough for its use.
    PREFERRED_WIDTH = 640   # Venue popup heroes are ~330 CSS px wide; 2x for retina
    THUMB_MIN_SIDE  = 96    # Act avatars are 32 CSS px circles; 3x for retina

    def self.extract_images(images_data)
      return {} unless images_data.is_a?(Array)

      usable = images_data.select { |img| img["url"].present? && !img["fallback"] }
      return {} if usable.empty?

      result = {}

      # One image per ratio: the narrowest at least PREFERRED_WIDTH wide, else the widest
      usable.group_by { |img| img["ratio"] || "unknown" }.each do |ratio, imgs|
        size_key = case ratio
        when "16_9", "16_9_large" then "large"
        when "3_2", "4_3" then "medium"
        when "1_1" then "square"
        else "standard"
        end

        result[size_key] ||= right_sized(imgs, PREFERRED_WIDTH)["url"]
      end

      # Fill in missing sizes so callers can always ask for any of them
      fallback_url = result.values_at("large", "medium", "standard", "square").compact.first
      %w[standard large medium square].each { |size| result[size] ||= fallback_url }

      result["thumb"] = thumbnail(usable)["url"]
      result
    end

    def self.right_sized(imgs, min_width)
      big_enough = imgs.select { |img| img["width"].to_i >= min_width }
      big_enough.min_by { |img| img["width"].to_i } || imgs.max_by { |img| img["width"].to_i }
    end

    # Smallest image whose shorter side still covers a retina avatar; images
    # without dimensions sort last so a known-small one wins when available
    def self.thumbnail(imgs)
      short_side = ->(img) { [ img["width"].to_i, img["height"].to_i ].min }
      big_enough = imgs.select { |img| short_side.(img) >= THUMB_MIN_SIDE }
      big_enough.min_by(&short_side) || imgs.max_by(&short_side)
    end
  end
end

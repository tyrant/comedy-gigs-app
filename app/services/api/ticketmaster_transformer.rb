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

      Rails.logger.info "=== TICKETMASTER VENUE DATA DEBUGGING ==="
      Rails.logger.info "Venue: #{venue['name']}"
      Rails.logger.info "Has images? #{venue['images'].present?}"
      if venue["images"].present?
        Rails.logger.info "Number of venue images: #{venue['images'].size}"
        Rails.logger.info "First image sample: #{venue['images'].first.inspect}"
      end

      result = {
        name: venue["name"],
        address: venue.dig("address", "line1"),
        city: venue.dig("city", "name"),
        country: venue.dig("country", "name"),
        latitude: venue.dig("location", "latitude")&.to_f,
        longitude: venue.dig("location", "longitude")&.to_f,
        description: venue["description"],
        capacity: venue["capacity"]&.to_i,
        external_ids: {
          "ticketmaster" => venue["id"]
        },
        images: extract_images(venue["images"])
      }

      Rails.logger.info "Final venue images: #{result[:images].inspect}"
      Rails.logger.info "=== END TICKETMASTER VENUE DATA DEBUGGING ==="

      result
    end

    def self.build_acts(attractions)
      return [] unless attractions

      Rails.logger.info "=== TICKETMASTER ACTS DATA DEBUGGING ==="
      Rails.logger.info "Number of attractions: #{attractions.size}"

      attractions.map do |act|
        Rails.logger.info "Processing act: #{act['name']}"
        Rails.logger.info "Has images? #{act['images'].present?}"
        if act["images"].present?
          Rails.logger.info "Number of act images: #{act['images'].size}"
          Rails.logger.info "First image sample: #{act['images'].first.inspect}"
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

        Rails.logger.info "Final act images for #{act['name']}: #{act_data[:images].inspect}"
        act_data
      end.tap do
        Rails.logger.info "=== END TICKETMASTER ACTS DATA DEBUGGING ==="
      end
    end

    def self.extract_social_links(act)
      return {} unless act["externalLinks"]

      {
        "twitter" => act.dig("externalLinks", "twitter", 0, "url"),
        "instagram" => act.dig("externalLinks", "instagram", 0, "url"),
        "facebook" => act.dig("externalLinks", "facebook", 0, "url")
      }.compact
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

    def self.extract_images(images_data)
      Rails.logger.info "=== TICKETMASTER IMAGE DATA DEBUGGING ==="
      Rails.logger.info "Raw images_data: #{images_data.inspect}"

      if !images_data.is_a?(Array)
        Rails.logger.warn "Images data is not an array: #{images_data.class}"
        return {}
      end

      if images_data.empty?
        Rails.logger.warn "Images data array is empty"
        return {}
      end

      result = {}
      best_images = {}

      # First pass: collect best images by ratio and width
      images_data.each_with_index do |img, index|
        Rails.logger.info "Processing image #{index}: #{img.inspect}"

        if !img["url"].present?
          Rails.logger.warn "Image #{index} has no URL"
          next
        end

        if img["fallback"]
          Rails.logger.info "Image #{index} is a fallback image, skipping"
          next
        end

        # Store best image for each ratio (prefer higher width)
        ratio = img["ratio"] || "unknown"
        width = img["width"] || 0

        if best_images[ratio].nil? || width > (best_images[ratio]["width"] || 0)
          best_images[ratio] = img
          Rails.logger.info "Stored best image for ratio #{ratio} (width: #{width})"
        end
      end

      Rails.logger.info "Best images by ratio: #{best_images.keys.join(', ')}"

      # Second pass: map ratios to our size categories
      best_images.each do |ratio, img|
        size_key = case ratio
        when "16_9", "16_9_large" then "large"
        when "3_2", "4_3" then "medium"
        when "1_1" then "square"
        else "standard"
        end

        # Only store if we don't already have this size
        if result[size_key].nil?
          result[size_key] = img["url"]
          Rails.logger.info "Mapped ratio #{ratio} to size #{size_key}: #{img['url']}"
        end
      end

      # Ensure all required sizes exist by creating fallbacks
      required_sizes = [ "standard", "large", "medium", "square" ]

      # If we have any image, use it as a base fallback
      fallback_url = nil
      [ "large", "medium", "standard", "square" ].each do |size|
        if result[size].present?
          fallback_url = result[size]
          break
        end
      end

      # Fill in missing sizes with fallbacks
      if fallback_url.present?
        required_sizes.each do |size|
          if result[size].nil?
            result[size] = fallback_url
            Rails.logger.info "Created fallback for missing size #{size}: #{fallback_url}"
          end
        end
      end

      Rails.logger.info "Final image result: #{result.inspect}"
      Rails.logger.info "=== END TICKETMASTER IMAGE DATA DEBUGGING ==="

      result
    end
  end
end

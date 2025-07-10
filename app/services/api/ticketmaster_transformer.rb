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
        venue: build_venue(event_data.dig('_embedded', 'venues', 0)),
        acts: build_acts(event_data.dig('_embedded', 'attractions'))
      }

      Rails.logger.debug "Transformed data: #{transformed.inspect}"
      transformed
    end

    private

    def self.comedy_event?(event)
      # Check if event has comedy segment and genre
      classifications = event.dig('classifications') || []
      classifications.any? do |c|
        c.dig('segment', 'id') == Api::TicketmasterClient::COMEDY_SEGMENT_ID &&
        c.dig('genre', 'id') == Api::TicketmasterClient::COMEDY_GENRE_ID
      end
    end

    def self.valid_event?(event)
      # Check for required fields
      return false unless event['name'].present?
      return false unless event.dig('dates', 'start', 'dateTime').present?
      return false unless event.dig('_embedded', 'venues').present?
      true
    end

    def self.build_gig(event)
      start_time = parse_datetime(event.dig('dates', 'start', 'dateTime'))
      # If no end time is provided, default to 2 hours after start
      end_time = parse_datetime(event.dig('dates', 'end', 'dateTime')) || (start_time + 2.hours)

      {
        name: event['name'],
        description: event.dig('description') || '',
        start_time: start_time,
        end_time: end_time,
        ticket_url: event.dig('url'),
        status: map_status(event.dig('dates', 'status', 'code')),
        external_ids: {
          'ticketmaster' => event['id']
        }
      }
    end

    def self.build_venue(venue)
      return nil unless venue

      {
        name: venue['name'],
        address: venue.dig('address', 'line1'),
        city: venue.dig('city', 'name'),
        country: venue.dig('country', 'name'),
        latitude: venue.dig('location', 'latitude')&.to_f,
        longitude: venue.dig('location', 'longitude')&.to_f,
        description: venue['description'],
        capacity: venue['capacity']&.to_i,
        external_ids: {
          'ticketmaster' => venue['id']
        },
        images: extract_images(venue['images'])
      }
    end

    def self.build_acts(attractions)
      return [] unless attractions

      attractions.map do |act|
        {
          name: act['name'],
          description: act['description'],
          social_links: extract_social_links(act),
          external_ids: {
            'ticketmaster' => act['id']
          },
          images: extract_images(act['images'])
        }
      end
    end

    def self.extract_social_links(act)
      return {} unless act['externalLinks']

      {
        'twitter' => act.dig('externalLinks', 'twitter', 0, 'url'),
        'instagram' => act.dig('externalLinks', 'instagram', 0, 'url'),
        'facebook' => act.dig('externalLinks', 'facebook', 0, 'url')
      }.compact
    end

    def self.parse_datetime(datetime_str)
      datetime_str ? Time.parse(datetime_str) : nil
    end

    def self.map_status(status_code)
      {
        'onsale' => 'scheduled',
        'cancelled' => 'cancelled',
        'postponed' => 'postponed',
        'offsale' => 'sold_out'
      }[status_code] || 'scheduled'
    end
    
    def self.extract_images(images_data)
      return {} unless images_data.is_a?(Array) && images_data.any?
      
      result = {}
      
      # Process images by ratio/size
      images_data.each do |img|
        next unless img['url'].present? && !img['fallback']
        
        # Map common ratios to size names
        size_key = case img['ratio']
          when '16_9', '16_9_large' then 'large'
          when '3_2', '4_3' then 'medium'
          when '1_1' then 'square'
          else 'standard'
        end
        
        # Only store the first image of each size (typically the best quality)
        result[size_key] ||= img['url']
      end
      
      result
    end
  end
end

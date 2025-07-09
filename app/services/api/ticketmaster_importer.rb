module Api
  class TicketmasterImporter
    def initialize
      @client = TicketmasterClient.new
      @notification_service = NotificationService.new
      @metrics = Metrics::ImportMetrics.new
    end

    def import_events(country_code: 'US')
      stats = {
        total_processed: 0,
        successful: 0,
        failed: 0,
        skipped: 0,
        rate_limited: 0,
        start_time: Time.current
      }

      page = 0

      begin
        loop do
          begin
            response = @client.fetch_comedy_events(country_code: country_code, page: page)
            events = response.dig('_embedded', 'events')
            break unless events&.any?

            events.each do |event|
              begin
                if import_event(event)
                  stats[:successful] += 1
                  stats[:total_processed] += 1
                else
                  stats[:skipped] += 1
                  stats[:total_processed] += 1
                end
              rescue StandardError => e
                stats[:failed] += 1
                notify_error(e, event, stats)
              end
            end

            page += 1
            break if page >= (response['page']['totalPages'] || 1)
          rescue Api::RateLimitError => e
            stats[:rate_limited] += 1
            stats[:end_time] = Time.current
            @metrics.record_import(stats)
            raise e
          end
        end

        stats[:end_time] = Time.current
        @metrics.record_import(stats)
        notify_success(stats)
        stats
      rescue StandardError => e
        stats[:end_time] = Time.current
        @metrics.record_import(stats)
        notify_error(e, nil, stats)
        stats
      end

      Rails.logger.info generate_stats_message(stats)
      stats
    end

    private

    def record_error(stats, error, event = nil)
      stats[:errors] << {
        type: error.class.name,
        message: error.message,
        event_name: event&.dig('name'),
        timestamp: Time.current
      }
      stats[:errors] = stats[:errors].last(10) # Keep only last 10 errors
    end

    def notify_error(error, event, stats)
      # Convert exception to a serializable hash instead of passing the raw exception
      error_data = if error.is_a?(Exception)
        {
          message: error.message,
          class: error.class.to_s,
          backtrace: error.backtrace&.first(10) || []
        }
      else
        { message: error.to_s, class: error.class.to_s }
      end
      
      # Make sure event is also serializable
      event_data = event.is_a?(Hash) ? event.slice('name', 'id') : nil
      
      @notification_service.notify_import_error(
        error: error_data,
        stats: stats.merge(event: event_data)
      )
    end

    def notify_success(stats)
      @notification_service.notify_import_success(stats)
    end

    def generate_stats_message(stats)
      duration = ((stats[:end_time] - stats[:start_time]) / 60.0).round(2)
      <<~MSG
        Import completed in #{duration} minutes
        Total processed: #{stats[:total_processed]}
        Successful: #{stats[:successful]}
        Failed: #{stats[:failed]}
        Skipped: #{stats[:skipped]}
        Rate limited: #{stats[:rate_limited]}
      MSG
    end

    

    def import_event(event_data)
      ActiveRecord::Base.transaction do
        transformed_data = TicketmasterTransformer.transform_event(event_data)
        return false unless transformed_data # Skip if transformation failed
        
        # Import venue
        venue = upsert_venue(transformed_data[:venue]) if transformed_data[:venue]
        return false unless venue # Skip if no valid venue
        
        # Import acts
        acts = transformed_data[:acts].map { |act_data| upsert_act(act_data) }.compact
        return false unless acts.any? # Skip if no valid acts
        
        # Import gig
        gig_data = transformed_data[:gig]
        gig_data[:venue] = venue
        gig = upsert_gig(gig_data)
        
        # Associate acts with gig
        gig.acts = acts
        
        true # Successfully imported
      end
    end

    def upsert_venue(venue_data)
      external_id = venue_data[:external_ids]['ticketmaster']
      venue = Venue.find_or_initialize_by(
        external_ids: { 'ticketmaster' => external_id }
      )
      venue.assign_attributes(venue_data)
      venue.save!
      venue
    end

    def upsert_act(act_data)
      external_id = act_data[:external_ids]['ticketmaster']
      act = Act.find_or_initialize_by(
        external_ids: { 'ticketmaster' => external_id }
      )
      act.assign_attributes(act_data)
      act.save!
      act
    end

    def upsert_gig(gig_data)
      external_id = gig_data[:external_ids]['ticketmaster']
      gig = Gig.find_or_initialize_by(
        external_ids: { 'ticketmaster' => external_id }
      )
      gig.assign_attributes(gig_data)
      gig.save!
      gig
    end
  end
end

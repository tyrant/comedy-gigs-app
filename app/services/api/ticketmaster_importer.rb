module Api
  class TicketmasterImporter < Importer
    def initialize
      @source = 'ticketmaster'
      @client = TicketmasterClient.new
      super
    end

    def import_events(country_code: "")
      @stats[:start_time] = Time.current

      page = 0

      begin
        loop do
          begin
            response = @client.fetch_comedy_events(country_code: country_code, page: page)
            events = response.dig("_embedded", "events")
            break unless events&.any?

            events.each do |event|
              begin
                if import_event(event)
                  @stats[:successful] += 1
                else
                  @stats[:skipped] += 1
                end

              rescue StandardError => e
                @stats[:failed] += 1
                notify_error(e, event)

              ensure
                @stats[:total_processed] += 1

              end
            end

            page += 1
            max_pages = TicketmasterClient::MAX_RESULTS / TicketmasterClient::PAGE_SIZE
            break if page >= [response.dig("page", "totalPages") || 1, max_pages].min

          rescue Api::RateLimitError => e
            @stats[:rate_limited] += 1
            @stats[:end_time] = Time.current
            @metrics.record_import(@stats)
            raise e
          end
        end

        @stats[:end_time] = Time.current
        @metrics.record_import(@stats)
        notify_success

      rescue StandardError => e
        @stats[:end_time] = Time.current
        @metrics.record_import(@stats)
        notify_error(e, nil)

      end

      Rails.logger.info generate_stats_message

      @stats
    end

    private

    def import_event(event_data)
      ActiveRecord::Base.transaction do
        transformed_data = TicketmasterTransformer.transform_event(event_data)
        return false unless transformed_data

        venue = upsert_venue(transformed_data[:venue]) if transformed_data[:venue]
        return false unless venue

        acts = transformed_data[:acts].map { |act_data| upsert_act(act_data) }.compact
        return false unless acts.any?

        gig_data = transformed_data[:gig]
        gig_data[:venue] = venue
        gig_data[:acts] = acts
        upsert_gig(gig_data)

        true
      end
    end
  end
end

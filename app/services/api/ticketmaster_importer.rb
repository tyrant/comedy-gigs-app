module Api
  class TicketmasterImporter < Importer
    HORIZON    = 365.days # Matches the UI's default one-year date filter
    WINDOW     = 7.days
    MIN_WINDOW = 1.day
    MAX_PAGES  = TicketmasterClient::MAX_RESULTS / TicketmasterClient::PAGE_SIZE

    def initialize
      @source = "ticketmaster"
      @client = TicketmasterClient.new
      super
    end

    def import_events(country_code: "", horizon: HORIZON)
      @stats[:start_time] = Time.current
      @country_code = country_code

      begin
        window_start = @stats[:start_time]
        horizon_end  = window_start + horizon

        while window_start < horizon_end
          window_end = [ window_start + WINDOW, horizon_end ].min
          import_window(window_start, window_end)
          window_start = window_end
        end

        @stats[:end_time] = Time.current
        @metrics.record_import(@stats)
        notify_success

      rescue Api::RateLimitError => e
        @stats[:rate_limited] += 1
        fail_import(e)

      rescue StandardError => e
        fail_import(e)

      end

      Rails.logger.info generate_stats_message

      @stats
    end

    private

    # The Discovery API rejects paging past 1000 results, so a window holding
    # more than that is halved until each half fits, or until it's a day wide.
    def import_window(starts_after, starts_before)
      page = 0

      loop do
        response = @client.fetch_comedy_events(country_code: @country_code, page: page,
                                               starts_after: starts_after, starts_before: starts_before)

        if page.zero? && too_many_results?(response) && (starts_before - starts_after) > MIN_WINDOW
          midpoint = starts_after + (starts_before - starts_after) / 2
          import_window(starts_after, midpoint)
          import_window(midpoint, starts_before)
          return
        end

        events = response.dig("_embedded", "events")
        break unless events&.any?

        events.each { |event| import_and_count(event) }

        page += 1
        break if page >= [ response.dig("page", "totalPages") || 1, MAX_PAGES ].min
      end
    end

    def too_many_results?(response)
      response.dig("page", "totalElements").to_i > TicketmasterClient::MAX_RESULTS
    end

    def import_and_count(event)
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

    def fail_import(error)
      @stats[:end_time] = Time.current
      @stats[:error] = { class: error.class.name, message: error.message }
      @metrics.record_import(@stats)
      notify_error(error, nil)
    end

    def import_event(event_data)
      ActiveRecord::Base.transaction do
        transformed_data = TicketmasterTransformer.transform_event(event_data)
        return false unless transformed_data

        venue = upsert_venue(transformed_data[:venue]) if transformed_data[:venue]
        return false unless venue

        acts = transformed_data[:acts].map { |act_data| upsert_act(act_data) }.compact.uniq
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

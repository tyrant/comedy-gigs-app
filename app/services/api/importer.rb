module Api
  class Importer
    def initialize
      @notification_service = NotificationService.new
      @metrics = Metrics::ImportMetrics.new
      @stats = {
        total_processed: 0,
        successful: 0,
        failed: 0,
        skipped: 0,
        rate_limited: 0
      }
    end

    private

    def upsert_gig(gig_data)
      gig = Gig.from_existing(gig_data, @source) || Gig.new

      gig_data[:external_ids] = gig.external_ids.merge(gig_data[:external_ids])
      gig.update!(gig_data)
      gig
    end

    def upsert_venue(venue_data)
      venue = Venue.from_existing(venue_data, @source) || Venue.new

      venue_data[:external_ids] = venue.external_ids.merge(venue_data[:external_ids])
      venue.update!(venue_data)
      venue
    end

    def upsert_act(act_data)
      act = Act.from_existing(act_data, @source) || Act.new

      act_data[:external_ids] = act.external_ids.merge(act_data[:external_ids])
      act_data[:images] = act.images.merge(act_data[:images]) if act_data[:images].present? && act.images.present?

      act.update!(act_data)
      act
    end

    def notify_error(error, event)
      # Convert exception to a serializable hash
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
      event_data = event.is_a?(Hash) ? event.slice("name", "id") : nil

      @notification_service.notify_import_error(
        error: error_data,
        stats: @stats.merge(event: event_data, source: @source)
      )
    end

    def notify_success
      @notification_service.notify_import_success(@stats.merge(source: @source))
    end

    def generate_stats_message
      duration = ((@stats[:end_time] - @stats[:start_time]) / 60.0).round(2)
      <<~MSG
        Eventfinda import completed in #{duration} minutes
        Total processed: #{@stats[:total_processed]}
        Successful: #{@stats[:successful]}
        Failed: #{@stats[:failed]}
        Skipped: #{@stats[:skipped]}
        Rate limited: #{@stats[:rate_limited]}
      MSG
    end
  end
end

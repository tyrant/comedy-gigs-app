module Api
  class Importer
    # How many per-event failures to keep for the monitor; the rest are counted
    MAX_ERROR_SAMPLES = 10

    def initialize
      @stats = {
        total_processed: 0,
        successful: 0,
        failed: 0,
        skipped: 0,
        rate_limited: 0,
        error_samples: []
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

    def record_event_error(error, event)
      Rails.logger.warn "#{@source} event #{event&.dig('id')} (#{event&.dig('name')}) failed: #{error.class}: #{error.message}"
      return if @stats[:error_samples].size >= MAX_ERROR_SAMPLES

      @stats[:error_samples] << "#{event&.dig('name')}: #{error.class}: #{error.message}".truncate(300)
    end

    def generate_stats_message
      duration = ((@stats[:end_time] - @stats[:start_time]) / 60.0).round(2)
      <<~MSG
        #{@source.titleize} import completed in #{duration} minutes
        Total processed: #{@stats[:total_processed]}
        Successful: #{@stats[:successful]}
        Failed: #{@stats[:failed]}
        Skipped: #{@stats[:skipped]}
        Rate limited: #{@stats[:rate_limited]}
      MSG
    end
  end
end

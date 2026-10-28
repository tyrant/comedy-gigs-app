module Api
  class Importer
    # How many per-event failures to keep for the monitor; the rest are counted
    MAX_ERROR_SAMPLES = 10

    # Whose details win when sources describe the same venue, act or gig
    SOURCE_PRIORITY = %w[ticketmaster eventfinda].freeze

    # Assigned whatever the priority, since they link records rather than describe them
    ASSOCIATIONS = %i[venue acts].freeze

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

    # Runs the import, recording a fatal error in the stats rather than
    # raising, so the rake task can report how far it got
    def run
      @stats[:start_time] = Time.current
      yield
    rescue RateLimitError => e
      @stats[:rate_limited] += 1
      record_failure(e)
    rescue StandardError => e
      record_failure(e)
    ensure
      @stats[:end_time] ||= Time.current
      Rails.logger.info generate_stats_message
    end

    # Imports one provider event; import_event returns false to skip it
    def import_and_count(event)
      if import_event(event)
        @stats[:successful] += 1
      else
        @stats[:skipped] += 1
      end
    rescue StandardError => e
      @stats[:failed] += 1
      record_event_error(e, event)
    ensure
      @stats[:total_processed] += 1
    end

    def record_failure(error)
      @stats[:end_time] = Time.current
      @stats[:error] = { class: error.class.name, message: error.message }
      Rails.logger.error "#{@source.titleize} import failed: #{error.class}: #{error.message}"
    end

    # A source with no lineup leaves a matched gig's acts alone
    def upsert_gig(gig_data)
      gig_data = gig_data.except(:acts) if gig_data[:acts].blank?
      save_merged(Gig.from_existing(gig_data, @source) || Gig.new, gig_data)
    end

    def upsert_venue(venue_data)
      venue = Venue.from_existing(venue_data, @source) || Venue.new
      save_merged(venue, located(venue, venue_data))
    end

    # Keeps what's already known about a venue when the source leaves it out,
    # and looks up the rest: coordinates from the address, city from the coordinates
    LOCATION_FIELDS = %i[latitude longitude city country].freeze

    def located(venue, data)
      data = data.merge(LOCATION_FIELDS.filter_map { |field| [ field, venue[field] ] if data[field].blank? && venue[field].present? }.to_h)

      if LOCATION_FIELDS.any? { |field| data[field].blank? }
        @venue_locator ||= VenueLocator.new
        @venue_locator.call(data)
      else
        data.except(:postcode, :country_code)
      end
    end

    def upsert_act(act_data)
      act = Act.from_existing(act_data, @source) || Act.new
      act_data = act_data.merge(images: act.images.merge(act_data[:images])) if act_data[:images].present? && act.images.present?
      save_merged(act, act_data)
    end

    # Records the source's ID on the record. When a source earlier in
    # SOURCE_PRIORITY also lists it, this one only fills in what's blank, so
    # the two don't overwrite each other's names and links on alternate nights.
    def save_merged(record, data)
      data = data.merge(external_ids: record.external_ids.merge(data[:external_ids]))
      data = data.select { |key, value| ASSOCIATIONS.include?(key) || key == :external_ids || record[key].blank? } if outranked?(record)
      record.update!(data)
      record
    end

    def outranked?(record)
      rank = SOURCE_PRIORITY.index(@source) || SOURCE_PRIORITY.size
      record.external_ids.keys.any? { |source| (SOURCE_PRIORITY.index(source) || SOURCE_PRIORITY.size) < rank }
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

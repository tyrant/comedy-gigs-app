module Api
  class Importer
    # How many per-event failures to keep for the monitor; the rest are counted
    MAX_ERROR_SAMPLES = 10

    # Whose details win when sources describe the same venue, act or gig
    SOURCE_PRIORITY = %w[ticketmaster eventfinda].freeze

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

    # Each upsert finds the record (RecordMatcher), saves the source's details
    # and links the source's ID to it. A source with no lineup leaves a matched
    # gig's acts alone.
    def upsert_gig(gig_data)
      gig_data = gig_data.except(:acts) if gig_data[:acts].blank?
      external_id, data = split_id(gig_data)
      save_merged(matcher.gig(@source, external_id, data) || Gig.new, data, external_id)
    end

    def upsert_venue(venue_data)
      external_id, data = split_id(venue_data)
      venue = matcher.venue(@source, external_id, data) || Venue.new
      save_merged(venue, located(venue, data), external_id)
    end

    def upsert_act(act_data)
      external_id, data = split_id(act_data)
      act = matcher.act(@source, external_id, data) || Act.new
      data = data.merge(images: act.images.merge(data[:images])) if data[:images].present? && act.images.present?
      save_merged(act, data, external_id)
    end

    def matcher = @matcher ||= RecordMatcher.new

    # Transformers give { external_ids: { source => id } }
    def split_id(data) = [ data.dig(:external_ids, @source).to_s, data.except(:external_ids) ]

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

    # Only the record's leading listing updates its details; any other just
    # fills in what's blank (including a lineup), so listings don't overwrite
    # each other on alternate nights. The venue is always set: it's how gigs match.
    def save_merged(record, data, external_id)
      listed = data
      data = data.select { |key, _value| key == :venue || record.public_send(key).blank? } unless leads?(record, external_id)
      data = show_over_package(record, listed, data) if record.is_a?(Gig) && record.persisted?
      record.update!(data)
      record.link_to!(@source, external_id) if external_id.present?
      record
    end

    # The leading listing is the first one linked from the highest-priority
    # source that lists the record: Ticketmaster over Eventfinda, and a show's
    # original listing over its VIP package
    def leads?(record, external_id)
      return true if record.new_record?

      listings = record.source_links.map { |link| [ rank(link.source), link.created_at, link.source, link.external_id ] }
      unless listings.any? { |_, _, source, id| source == @source && id == external_id }
        listings << [ rank(@source), Time.current, @source, external_id ]
      end

      _, _, source, id = listings.min_by { |rank, created_at, *| [ rank, created_at ] }
      source == @source && id == external_id
    end

    def rank(source) = SOURCE_PRIORITY.index(source) || SOURCE_PRIORITY.size

    # A show's own listing names the gig and gives its ticket link, whichever
    # listing came first; a ticket package ("... | Official Ticket + Hotel
    # Packages") never does
    def show_over_package(gig, listed, data)
      if MatchKey.package_listing?(gig.name) && !MatchKey.package_listing?(listed[:name])
        data.merge(listed.slice(:name, :ticket_url))
      elsif MatchKey.package_listing?(listed[:name]) && gig.name.present? && !MatchKey.package_listing?(gig.name)
        data.except(:name, :ticket_url)
      else
        data
      end
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

module Api
  # Imports upcoming comedy from Eventfinda (New Zealand): one venue per
  # event, and one gig per upcoming session.
  class EventfindaImporter < Importer
    def initialize
      @source = "eventfinda"
      @client = EventfindaClient.new
      super
      @stats[:gigs] = 0
    end

    def import_events
      run do
        offset = 0

        loop do
          response = @client.fetch_comedy_events(offset:)
          events = response["events"] || []
          events.each { |event| import_and_count(event) }

          offset += EventfindaClient::PAGE_SIZE
          break if events.empty? || offset >= response.dig("@attributes", "count").to_i
        end
      end

      @stats
    end

    private

    def import_event(event)
      transformed = EventfindaTransformer.transform_event(event)
      return false unless transformed

      ActiveRecord::Base.transaction do
        venue = upsert_venue(transformed[:venue])
        transformed[:gigs].each { |gig_data| upsert_gig(gig_data.merge(venue:)) }
      end

      @stats[:gigs] += transformed[:gigs].size
      true
    end

    def generate_stats_message
      super + "Gigs: #{@stats[:gigs]}\n"
    end
  end
end

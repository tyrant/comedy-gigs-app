module Api
  # Imports upcoming UK comedy from Skiddle: a venue, a gig and any listed
  # artists per event. Few events list artists, so gigs also get the known
  # comedians their title names.
  class SkiddleImporter < Importer
    HORIZON = 365.days # as Ticketmaster's

    def initialize
      @source = "skiddle"
      @client = SkiddleClient.new
      super
      @act_matcher = ActMatcher.new
    end

    def import_events(horizon: HORIZON)
      run do
        offset = 0
        seen = Set.new # pages can overlap a little as listings change

        loop do
          response = @client.fetch_comedy_events(offset:, to: Date.current + horizon)
          events = response["results"] || []
          events.each { |event| import_and_count(event) if seen.add?(event["id"]) }

          offset += events.size
          break if events.empty? || offset >= response["totalcount"].to_i
        end
      end

      @stats
    end

    private

    def import_event(event)
      transformed = SkiddleTransformer.transform_event(event)
      return false unless transformed

      ActiveRecord::Base.transaction do
        acts = (transformed[:acts].map { |act_data| upsert_act(act_data) } + @act_matcher.acts_in(transformed[:gig][:name])).uniq
        venue = upsert_venue(transformed[:venue])
        upsert_gig(transformed[:gig].merge(venue:, acts:))
      end

      true
    end
  end
end

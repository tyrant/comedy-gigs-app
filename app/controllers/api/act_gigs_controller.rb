module Api
  # One act's gigs for the current dates, wherever they are, with what's known
  # about the act. The act filter doesn't apply: this is the act's own list.
  class ActGigsController < BaseController
    def index
      act = Act.find(params[:act_id])
      gigs = Gig.filtered_for_api(filter_params.except(:act_ids)).joins(:acts).where(acts: { id: act.id })
        .joins(:venue).where.not(venues: { latitude: nil }).where.not(venues: { longitude: nil }) # those on the map

      render_cached(act, gigs, Venue.maximum(:updated_at)) do
        render json: {
          act: act_json(act),
          gigs: gigs.includes(:venue, :source_links).order(:start_time, :id).map { |gig| gig_json(gig) }
        }
      end
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    private

    def act_json(act)
      banner = act.primary_image_url("large")

      {
        id: act.id,
        name: act.name,
        image: banner == Act::IMAGE_PLACEHOLDER ? nil : banner,
        # Ticketmaster's description if it ever sends one, else Wikipedia's, credited
        description: act.description.presence || act.bio,
        description_url: (act.bio_url if act.description.blank? && act.bio.present?),
        links: act.official_links
      }
    end

    def gig_json(gig)
      venue = gig.venue

      {
        id: gig.id,
        name: gig.name.strip,
        start_time: gig.start_time,
        status: gig.status,
        ticket_url: gig.ticket_url,
        sources: gig.source_links.map(&:source).uniq.sort, # Skiddle's terms: credit it wherever its data shows
        venue: { id: venue.id, name: venue.name, city: venue.city, timezone: venue.timezone, lat: venue.latitude.to_f, lng: venue.longitude.to_f }
      }
    end
  end
end

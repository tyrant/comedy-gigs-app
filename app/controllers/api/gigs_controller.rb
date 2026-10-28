module Api
  # One venue's matching gigs and lineups, fetched when its popup opens
  class GigsController < BaseController
    def index
      venue = Venue.find(params[:venue_id])
      gigs = Gig.filtered_for_api(filter_params).where(venue:)

      render_cached(venue, gigs, Act.maximum(:updated_at)) do
        render json: {
          venue: venue_json(venue),
          gigs: gigs.includes(:acts).order(:start_time, :id).map { |gig| gig_json(gig) }
        }
      end
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    private

    def venue_json(venue)
      {
        id: venue.id,
        name: venue.name,
        address: venue.address,
        city: venue.city,
        timezone: venue.timezone,
        image: venue.primary_image_url,
        website: venue.website
      }
    end

    def gig_json(gig)
      {
        id: gig.id,
        name: gig.name.strip,
        start_time: gig.start_time,
        status: gig.status,
        ticket_url: gig.ticket_url,
        acts: gig.acts.sort_by(&:name).map { |act| { id: act.id, name: act.name, image: act.primary_image_url } }
      }
    end
  end
end

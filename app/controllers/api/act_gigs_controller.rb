module Api
  # One act's gigs for the current dates, wherever they are, with what's known
  # about the act and its tours. The act filter doesn't apply: this is the
  # act's own list. With tour_id, just that tour's gigs; the tours list stays
  # whole, with how many gigs each has for the dates.
  class ActGigsController < BaseController
    include GigPrices

    def index
      act = Act.find(params[:act_id])
      all_gigs = Gig.filtered_for_api(filter_params.except(:act_ids, :tour_id)).joins(:acts).where(acts: { id: act.id })
        .joins(:venue).where.not(venues: { latitude: nil }).where.not(venues: { longitude: nil }) # those on the map
      gigs = all_gigs.on_tour(params[:tour_id])

      render_cached(act, gigs, Venue.maximum(:updated_at), act.tours.maximum(:updated_at)) do
        render json: {
          act: act_json(act),
          tours: tours_json(act, all_gigs),
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

    # The act's tours with gigs for these dates, the biggest first
    def tours_json(act, gigs)
      counts = Tour.where(act:).joins(:gigs).merge(Gig.where(id: gigs.select(:id))).group(:id).count
      act.tours.select { |tour| counts[tour.id].to_i.positive? }
        .sort_by { |tour| [ -counts[tour.id], tour.name ] }
        .map { |tour| { id: tour.id, name: tour.name, gigs: counts[tour.id] } }
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
        **prices_json(gig),
        venue: { id: venue.id, name: venue.name, city: venue.city, timezone: venue.timezone, lat: venue.latitude.to_f, lng: venue.longitude.to_f }
      }
    end
  end
end

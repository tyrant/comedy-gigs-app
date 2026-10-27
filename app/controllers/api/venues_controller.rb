module Api
  # Every venue with a gig matching the filters, worldwide. The map clusters
  # these itself, so panning and zooming never go back to the server.
  class VenuesController < BaseController
    def index
      gigs = Gig.filtered_for_api(filter_params)

      render_cached(gigs, Venue.maximum(:updated_at)) do
        rows = Venue.joins(:gigs).merge(gigs)
          .where.not(latitude: nil).where.not(longitude: nil)
          .group(:id)
          .order(:id)
          .pluck(:id, :name, :latitude, :longitude, Arel.sql("COUNT(gigs.id)"))

        render json: rows.map { |id, name, lat, lng, count|
          { id:, name:, lat: lat.to_f, lng: lng.to_f, gigs: count }
        }
      end
    end
  end
end

module Api
  class GigsController < ApplicationController
    def index
      scope = Gig.includes(:venue)

      if bounds_params_present?
        sw = [params[:south].to_f, params[:west].to_f]
        ne = [params[:north].to_f, params[:east].to_f]

        Rails.logger.info "Searching within bounds: SW=#{sw.inspect}, NE=#{ne.inspect}"

        scope = scope.joins(:venue).merge(Venue.within_bounding_box([sw, ne]))
        
        Rails.logger.info "Found #{scope.count} gigs"
      end

      render json: scope.as_json(include: {
        venue: {
          methods: [:latitude, :longitude]
        }
      })
    end

    private

    def bounds_params_present?
      params[:north].present? && params[:south].present? &&
      params[:east].present? && params[:west].present?
    end
  end
end

module Api
  class GigsController < ApplicationController
    def index
      scope = Gig.includes(:venue, :acts)

      if bounds_params_present?
        sw = [ params[:south].to_f, params[:west].to_f ]
        ne = [ params[:north].to_f, params[:east].to_f ]

        scope = scope.joins(:venue).merge(Venue.within_bounding_box([ sw, ne ]))
      end

      if params[:act_ids].present?
        act_ids = params[:act_ids].split(",")

        gig_ids_with_acts = Gig.joins(:acts).where(acts: { id: act_ids }).distinct.pluck(:id)
        scope = scope.where(id: gig_ids_with_acts)
      end

      if params[:start_date].present?
        start_date = Date.parse(params[:start_date]) rescue false
        scope = scope.where("start_time >= ?", start_date.beginning_of_day) if start_date
      end

      if params[:end_date].present?
        end_date = Date.parse(params[:end_date]) rescue false
        scope = scope.where("start_time <= ?", end_date.end_of_day) if end_date
      end

      @gigs = scope.order(:id).to_a

      render json: @gigs.map { |gig|
        gig_json = gig.as_json
        gig_json["venue"] = gig.venue.as_json(methods: [ :latitude, :longitude, :primary_image_url ])
        gig_json["acts"] = gig.acts.map { |act| act.as_json(methods: [ :primary_image_url ]) }
        gig_json
      }
    end

    private

    def bounds_params_present?
      params[:north].present? && params[:south].present? &&
      params[:east].present? && params[:west].present?
    end
  end
end

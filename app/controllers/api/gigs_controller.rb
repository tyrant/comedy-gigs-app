module Api
  class GigsController < ApplicationController
    def index
      @gigs = Gig.filtered_for_api(params).to_a
      render json: Gig.serialize_for_api(@gigs)
    end
  end
end

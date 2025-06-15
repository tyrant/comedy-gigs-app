module Api
  class GigsController < ApplicationController
    def index
      gigs = Gig.includes(:venue).all
      render json: gigs.as_json(include: {
        venue: {
          methods: [:latitude, :longitude]
        }
      })
    end
  end
end

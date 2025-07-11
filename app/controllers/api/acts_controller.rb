module Api
  class ActsController < ApplicationController
    def index
      @acts = Act.order(:name)

      render json: @acts.map { |act|
        {
          id: act.id,
          name: act.name,
          primary_image_url: act.primary_image_url
        }
      }
    end
  end
end

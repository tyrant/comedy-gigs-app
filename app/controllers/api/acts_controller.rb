module Api
  class ActsController < ApplicationController
    def index
      @acts = Act.select(:id, :name).order(:name)
      render json: @acts
    end
  end
end

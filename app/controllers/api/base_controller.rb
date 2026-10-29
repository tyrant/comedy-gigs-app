module Api
  class BaseController < ActionController::API
    include ActionController::ConditionalGet

    private

    def filter_params
      params.permit(:start_date, :end_date, :act_ids, :tour_id, :upcoming)
    end

    # Renders unless the client's copy is current. A relation's cache key
    # covers its SQL, row count and newest updated_at, so it changes with the
    # filters, with imports and with deletions. Browsers always revalidate,
    # which costs one small query and an empty 304.
    def render_cached(*keys)
      expires_in 0, public: true, must_revalidate: true
      yield if stale?(etag: keys, public: true)
    end
  end
end

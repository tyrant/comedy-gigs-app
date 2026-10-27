module Api
  # Typeahead for the act filter. With ?ids=1,2 it returns exactly those acts,
  # for restoring a shared URL; with ?q= it searches names; with neither it
  # suggests the acts with the most upcoming gigs.
  class ActsController < BaseController
    LIMIT = 20

    UPCOMING_GIGS = <<~SQL.squish
      (SELECT COUNT(*) FROM acts_gigs
        JOIN gigs ON gigs.id = acts_gigs.gig_id
        WHERE acts_gigs.act_id = acts.id
          AND gigs.start_time >= CURRENT_DATE
          AND gigs.status <> 'cancelled')
    SQL

    def index
      acts = Act.select(:id, :name, :images, "#{UPCOMING_GIGS} AS upcoming_gigs")

      acts =
        if params[:ids].present?
          acts.where(id: params[:ids].to_s.split(",")).order(:name)
        elsif params[:q].present?
          search(acts, params[:q].to_s.strip)
        else
          acts.order(Arel.sql("upcoming_gigs DESC"), :name).limit(LIMIT)
        end

      render_cached(acts, Date.current) do
        render json: acts.map { |act|
          { id: act.id, name: act.name, image: act.primary_image_url, upcoming_gigs: act.upcoming_gigs }
        }
      end
    end

    private

    # Acts with gigs coming up first, then names starting with the query, then the rest
    def search(acts, query)
      term = Act.sanitize_sql_like(query)

      acts.where("acts.name ILIKE ?", "%#{term}%")
        .order(Arel.sql("#{UPCOMING_GIGS} = 0"))
        .order(Act.sanitize_sql_for_order([ Arel.sql("acts.name ILIKE ? DESC"), "#{term}%" ]))
        .order(:name)
        .limit(LIMIT)
    end
  end
end

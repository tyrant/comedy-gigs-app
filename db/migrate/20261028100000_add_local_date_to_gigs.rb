# Each gig's date on the venue's own calendar, so the date filters are a plain
# indexed comparison instead of a time zone conversion per row per request.
class AddLocalDateToGigs < ActiveRecord::Migration[8.1]
  def up
    add_column :gigs, :local_date, :date

    # Venues with no time zone, or one Postgres doesn't know, count as UTC
    execute <<~SQL
      UPDATE gigs
      SET local_date = (gigs.start_time AT TIME ZONE 'UTC' AT TIME ZONE COALESCE(zones.name, 'UTC'))::date
      FROM venues
      LEFT JOIN pg_timezone_names zones ON zones.name = venues.timezone
      WHERE venues.id = gigs.venue_id
    SQL

    add_index :gigs, :local_date, where: "status <> 'cancelled'", name: "index_gigs_on_local_date_live"
  end

  def down
    remove_index :gigs, name: "index_gigs_on_local_date_live"
    remove_column :gigs, :local_date
  end
end

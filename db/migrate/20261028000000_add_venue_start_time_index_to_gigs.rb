class AddVenueStartTimeIndexToGigs < ActiveRecord::Migration[8.1]
  def change
    # Serves the venue summary and per-venue gig lists, which never show cancellations
    add_index :gigs, [ :venue_id, :start_time ], where: "status <> 'cancelled'", name: "index_gigs_on_venue_id_and_start_time_live"
  end
end

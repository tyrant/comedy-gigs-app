# The events table predates gigs and was never used
class DropEvents < ActiveRecord::Migration[8.1]
  def change
    reversible do |direction|
      direction.up do
        rows = select_value("SELECT COUNT(*) FROM events").to_i
        raise "events has #{rows} rows; refusing to drop it without a look" if rows.positive?
      end
    end

    drop_table :events do |t|
      t.string :name
      t.datetime :start_time
      t.string :ticket_url
      t.references :venue, null: false, foreign_key: true
      t.timestamps
    end
  end
end

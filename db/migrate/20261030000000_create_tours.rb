# Acts' tours, worked out from their gigs' names (TourFinder): none of the
# sources mark them
class CreateTours < ActiveRecord::Migration[8.1]
  def change
    create_table :tours do |t|
      t.references :act, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :key, null: false # the name, normalized, without "tour" or a year: what its gigs' titles share
      t.timestamps
    end
    add_index :tours, [ :act_id, :key ], unique: true

    create_table :gigs_tours, id: false do |t|
      t.references :gig, null: false, foreign_key: { on_delete: :cascade }
      t.references :tour, null: false, foreign_key: { on_delete: :cascade }, index: false
    end
    add_index :gigs_tours, [ :tour_id, :gig_id ], unique: true
  end
end

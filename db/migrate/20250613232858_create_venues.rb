class CreateVenues < ActiveRecord::Migration[8.0]
  def change
    create_table :venues do |t|
      t.string :name, null: false
      t.string :address, null: false
      t.string :city, null: false
      t.string :country, null: false
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.text :description
      t.integer :capacity
      t.jsonb :external_ids, default: {}

      t.timestamps
    end

    add_index :venues, :name
    add_index :venues, [ :latitude, :longitude ]
    add_index :venues, :external_ids, using: :gin
    add_index :venues, :city
    add_index :venues, :country
  end
end

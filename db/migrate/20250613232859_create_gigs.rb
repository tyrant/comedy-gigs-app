class CreateGigs < ActiveRecord::Migration[8.0]
  def change
    create_table :gigs do |t|
      t.string :name, null: false
      t.datetime :start_time, null: false
      t.datetime :end_time
      t.text :description
      t.string :ticket_url
      t.string :status, default: 'scheduled'
      t.references :venue, null: false, foreign_key: true
      t.jsonb :external_ids, default: {}

      t.timestamps
    end

    add_index :gigs, :name
    add_index :gigs, :start_time
    add_index :gigs, :status
    add_index :gigs, :external_ids, using: :gin

    # Create join table for acts and gigs (many-to-many)
    create_table :acts_gigs do |t|
      t.references :act, null: false, foreign_key: true
      t.references :gig, null: false, foreign_key: true
      t.timestamps
    end

    add_index :acts_gigs, [:act_id, :gig_id], unique: true
  end
end

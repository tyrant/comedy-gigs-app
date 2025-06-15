class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events do |t|
      t.string :name
      t.datetime :start_time
      t.string :ticket_url
      t.references :venue, null: false, foreign_key: true

      t.timestamps
    end
  end
end

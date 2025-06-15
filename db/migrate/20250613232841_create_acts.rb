class CreateActs < ActiveRecord::Migration[8.0]
  def change
    create_table :acts do |t|
      t.string :name, null: false
      t.text :description
      t.jsonb :social_links, default: {}
      t.jsonb :external_ids, default: {}

      t.timestamps
    end

    add_index :acts, :name
    add_index :acts, :external_ids, using: :gin
  end
end

class AddImagesToActsAndVenues < ActiveRecord::Migration[8.0]
  def change
    add_column :acts, :images, :jsonb, default: {}
    add_column :venues, :images, :jsonb, default: {}
    
    add_index :acts, :images, using: :gin
    add_index :venues, :images, using: :gin
  end
end

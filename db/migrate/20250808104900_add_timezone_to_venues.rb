class AddTimezoneToVenues < ActiveRecord::Migration[8.0]
  def change
    add_column :venues, :timezone, :string
    add_index :venues, :timezone
  end
end

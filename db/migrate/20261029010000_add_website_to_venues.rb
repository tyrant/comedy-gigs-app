class AddWebsiteToVenues < ActiveRecord::Migration[8.1]
  def change
    add_column :venues, :website, :string
  end
end

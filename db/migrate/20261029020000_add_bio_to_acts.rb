class AddBioToActs < ActiveRecord::Migration[8.1]
  def change
    add_column :acts, :bio, :text
    add_column :acts, :bio_url, :string
    add_column :acts, :bio_checked_at, :datetime
  end
end

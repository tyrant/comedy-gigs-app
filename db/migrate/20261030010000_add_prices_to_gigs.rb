# What tickets cost, as far as the sources say: a range (all three sources,
# patchily) and, from Eventfinda, each ticket type with its availability
class AddPricesToGigs < ActiveRecord::Migration[8.1]
  def change
    add_column :gigs, :price_min, :decimal, precision: 10, scale: 2
    add_column :gigs, :price_max, :decimal, precision: 10, scale: 2
    add_column :gigs, :currency, :string, limit: 3
    add_column :gigs, :ticket_tiers, :jsonb, null: false, default: [] # [ { name, price, sold_out, few_left } ]
  end
end

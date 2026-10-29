# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_30_010000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "acts", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.jsonb "social_links", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "images", default: {}
    t.string "match_key"
    t.text "bio"
    t.string "bio_url"
    t.datetime "bio_checked_at"
    t.index ["images"], name: "index_acts_on_images", using: :gin
    t.index ["match_key"], name: "index_acts_on_match_key"
    t.index ["name"], name: "index_acts_on_name"
  end

  create_table "acts_gigs", force: :cascade do |t|
    t.bigint "act_id", null: false
    t.bigint "gig_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["act_id", "gig_id"], name: "index_acts_gigs_on_act_id_and_gig_id", unique: true
    t.index ["act_id"], name: "index_acts_gigs_on_act_id"
    t.index ["gig_id"], name: "index_acts_gigs_on_gig_id"
  end

  create_table "gigs", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "start_time", null: false
    t.datetime "end_time"
    t.text "description"
    t.string "ticket_url"
    t.string "status", default: "scheduled"
    t.bigint "venue_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "local_date"
    t.decimal "price_min", precision: 10, scale: 2
    t.decimal "price_max", precision: 10, scale: 2
    t.string "currency", limit: 3
    t.jsonb "ticket_tiers", default: [], null: false
    t.index ["local_date"], name: "index_gigs_on_local_date_live", where: "((status)::text <> 'cancelled'::text)"
    t.index ["name"], name: "index_gigs_on_name"
    t.index ["start_time"], name: "index_gigs_on_start_time"
    t.index ["status"], name: "index_gigs_on_status"
    t.index ["venue_id", "start_time"], name: "index_gigs_on_venue_id_and_start_time_live", where: "((status)::text <> 'cancelled'::text)"
    t.index ["venue_id"], name: "index_gigs_on_venue_id"
  end

  create_table "gigs_tours", id: false, force: :cascade do |t|
    t.bigint "gig_id", null: false
    t.bigint "tour_id", null: false
    t.index ["gig_id"], name: "index_gigs_tours_on_gig_id"
    t.index ["tour_id", "gig_id"], name: "index_gigs_tours_on_tour_id_and_gig_id", unique: true
  end

  create_table "source_links", force: :cascade do |t|
    t.string "source", null: false
    t.string "external_id", null: false
    t.string "linkable_type", null: false
    t.bigint "linkable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["linkable_type", "linkable_id"], name: "index_source_links_on_linkable_type_and_linkable_id"
    t.index ["linkable_type", "source", "external_id"], name: "index_source_links_on_external_id", unique: true
  end

  create_table "tours", force: :cascade do |t|
    t.bigint "act_id", null: false
    t.string "name", null: false
    t.string "key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["act_id", "key"], name: "index_tours_on_act_id_and_key", unique: true
    t.index ["act_id"], name: "index_tours_on_act_id"
  end

  create_table "venues", force: :cascade do |t|
    t.string "name", null: false
    t.string "address", null: false
    t.string "city", null: false
    t.string "country", null: false
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.text "description"
    t.integer "capacity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "images", default: {}
    t.string "timezone"
    t.string "match_key"
    t.string "website"
    t.index ["city"], name: "index_venues_on_city"
    t.index ["country"], name: "index_venues_on_country"
    t.index ["images"], name: "index_venues_on_images", using: :gin
    t.index ["latitude", "longitude"], name: "index_venues_on_latitude_and_longitude"
    t.index ["match_key"], name: "index_venues_on_match_key"
    t.index ["name"], name: "index_venues_on_name"
    t.index ["timezone"], name: "index_venues_on_timezone"
  end

  add_foreign_key "acts_gigs", "acts"
  add_foreign_key "acts_gigs", "gigs"
  add_foreign_key "gigs", "venues"
  add_foreign_key "gigs_tours", "gigs", on_delete: :cascade
  add_foreign_key "gigs_tours", "tours", on_delete: :cascade
  add_foreign_key "tours", "acts", on_delete: :cascade
end

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

ActiveRecord::Schema[8.0].define(version: 2025_06_14_101045) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "acts", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.jsonb "social_links", default: {}
    t.jsonb "external_ids", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_ids"], name: "index_acts_on_external_ids", using: :gin
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

  create_table "events", force: :cascade do |t|
    t.string "name"
    t.datetime "start_time"
    t.string "ticket_url"
    t.bigint "venue_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["venue_id"], name: "index_events_on_venue_id"
  end

  create_table "gigs", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "start_time", null: false
    t.datetime "end_time"
    t.text "description"
    t.string "ticket_url"
    t.string "status", default: "scheduled"
    t.bigint "venue_id", null: false
    t.jsonb "external_ids", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_ids"], name: "index_gigs_on_external_ids", using: :gin
    t.index ["name"], name: "index_gigs_on_name"
    t.index ["start_time"], name: "index_gigs_on_start_time"
    t.index ["status"], name: "index_gigs_on_status"
    t.index ["venue_id"], name: "index_gigs_on_venue_id"
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
    t.jsonb "external_ids", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["city"], name: "index_venues_on_city"
    t.index ["country"], name: "index_venues_on_country"
    t.index ["external_ids"], name: "index_venues_on_external_ids", using: :gin
    t.index ["latitude", "longitude"], name: "index_venues_on_latitude_and_longitude"
    t.index ["name"], name: "index_venues_on_name"
  end

  add_foreign_key "acts_gigs", "acts"
  add_foreign_key "acts_gigs", "gigs"
  add_foreign_key "events", "venues"
  add_foreign_key "gigs", "venues"
end

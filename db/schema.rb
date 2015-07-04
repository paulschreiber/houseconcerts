# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150704002343) do

  create_table "artists", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.string   "slug",       limit: 255
    t.string   "url",        limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "artists", ["name"], name: "index_artists_on_name", using: :btree
  add_index "artists", ["slug"], name: "index_artists_on_slug", unique: true, using: :btree

  create_table "opens", force: :cascade do |t|
    t.string   "tag",        limit: 255
    t.string   "ip_address", limit: 255
    t.string   "email",      limit: 255
    t.boolean  "open"
    t.boolean  "click"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "people", force: :cascade do |t|
    t.string   "uniqid",             limit: 255
    t.string   "first_name",         limit: 255
    t.string   "last_name",          limit: 255
    t.string   "email",              limit: 255
    t.string   "postcode",           limit: 255
    t.string   "notes",              limit: 255
    t.string   "status",             limit: 255
    t.string   "ip_address",         limit: 255
    t.string   "removal_ip_address", limit: 255
    t.datetime "removed_at"
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
  end

  add_index "people", ["email"], name: "index_people_on_email", using: :btree
  add_index "people", ["first_name"], name: "index_people_on_first_name", using: :btree
  add_index "people", ["last_name"], name: "index_people_on_last_name", using: :btree
  add_index "people", ["status"], name: "index_people_on_status", using: :btree
  add_index "people", ["uniqid"], name: "index_people_on_uniqid", unique: true, using: :btree

  create_table "people_venue_groups", id: false, force: :cascade do |t|
    t.integer "person_id",      limit: 4, null: false
    t.integer "venue_group_id", limit: 4, null: false
  end

  add_index "people_venue_groups", ["person_id", "venue_group_id"], name: "index_people_venue_groups_on_person_id_and_venue_group_id", using: :btree
  add_index "people_venue_groups", ["venue_group_id", "person_id"], name: "index_people_venue_groups_on_venue_group_id_and_person_id", using: :btree

  create_table "performances", force: :cascade do |t|
    t.integer  "show_id",    limit: 4
    t.integer  "artist_id",  limit: 4
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
  end

  add_index "performances", ["artist_id"], name: "index_performances_on_artist_id", using: :btree
  add_index "performances", ["show_id"], name: "index_performances_on_show_id", using: :btree

  create_table "rsvps", force: :cascade do |t|
    t.integer  "show_id",      limit: 4
    t.string   "first_name",   limit: 255
    t.string   "last_name",    limit: 255
    t.string   "email",        limit: 255
    t.string   "postcode",     limit: 255
    t.integer  "seats",        limit: 4
    t.string   "response",     limit: 255
    t.string   "confirmed",    limit: 255
    t.datetime "confirmed_at"
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  add_index "rsvps", ["confirmed"], name: "index_rsvps_on_confirmed", using: :btree
  add_index "rsvps", ["email"], name: "index_rsvps_on_email", using: :btree
  add_index "rsvps", ["response"], name: "index_rsvps_on_response", using: :btree
  add_index "rsvps", ["show_id"], name: "index_rsvps_on_show_id", using: :btree

  create_table "shows", force: :cascade do |t|
    t.datetime "start"
    t.datetime "end"
    t.string   "slug",       limit: 255
    t.string   "status",     limit: 255
    t.text     "blurb",      limit: 65535
    t.integer  "price",      limit: 4
    t.integer  "venue_id",   limit: 4
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  add_index "shows", ["slug"], name: "index_shows_on_slug", unique: true, using: :btree
  add_index "shows", ["start"], name: "index_shows_on_start", using: :btree
  add_index "shows", ["status"], name: "index_shows_on_status", using: :btree
  add_index "shows", ["venue_id"], name: "index_shows_on_venue_id", using: :btree

  create_table "venue_groups", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.integer  "venue_id",   limit: 4
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "venue_groups", ["venue_id"], name: "index_venue_groups_on_venue_id", using: :btree

  create_table "venue_groups_venues", id: false, force: :cascade do |t|
    t.integer "venue_id",       limit: 4, null: false
    t.integer "venue_group_id", limit: 4, null: false
  end

  add_index "venue_groups_venues", ["venue_group_id", "venue_id"], name: "index_venue_groups_venues_on_venue_group_id_and_venue_id", using: :btree
  add_index "venue_groups_venues", ["venue_id", "venue_group_id"], name: "index_venue_groups_venues_on_venue_id_and_venue_group_id", using: :btree

  create_table "venues", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.string   "address",    limit: 255
    t.string   "city",       limit: 255
    t.string   "province",   limit: 255
    t.string   "postcode",   limit: 255
    t.string   "country",    limit: 255
    t.integer  "capacity",   limit: 4
    t.string   "slug",       limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "venues", ["name"], name: "index_venues_on_name", using: :btree
  add_index "venues", ["slug"], name: "index_venues_on_slug", unique: true, using: :btree

  add_foreign_key "performances", "artists"
  add_foreign_key "performances", "shows"
  add_foreign_key "rsvps", "shows"
  add_foreign_key "shows", "venues"
  add_foreign_key "venue_groups", "venues"
end

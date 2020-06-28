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

ActiveRecord::Schema.define(version: 2019_05_22_155544) do

  create_table "admins", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true
  end

  create_table "artists", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "name"
    t.string "slug"
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_artists_on_name"
    t.index ["slug"], name: "index_artists_on_slug", unique: true
  end

  create_table "artists_shows", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "artist_id", null: false
    t.integer "show_id", null: false
    t.index ["artist_id", "show_id"], name: "index_artists_shows_on_artist_id_and_show_id"
    t.index ["show_id", "artist_id"], name: "index_artists_shows_on_show_id_and_artist_id"
  end

  create_table "friendly_id_slugs", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at"
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_id"
    t.index ["sluggable_type"], name: "index_friendly_id_slugs_on_sluggable_type"
  end

  create_table "opens", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "tag"
    t.string "ip_address"
    t.string "email"
    t.boolean "open"
    t.boolean "click"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "people", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "uniqid"
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.string "phone_number"
    t.string "postcode"
    t.string "notes"
    t.string "status"
    t.string "ip_address"
    t.string "removal_ip_address"
    t.datetime "removed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_people_on_email", unique: true
    t.index ["first_name"], name: "index_people_on_first_name"
    t.index ["last_name"], name: "index_people_on_last_name"
    t.index ["status"], name: "index_people_on_status"
    t.index ["uniqid"], name: "index_people_on_uniqid", unique: true
  end

  create_table "people_venue_groups", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "person_id", null: false
    t.integer "venue_group_id", null: false
    t.index ["person_id", "venue_group_id"], name: "index_people_venue_groups_on_person_id_and_venue_group_id"
    t.index ["venue_group_id", "person_id"], name: "index_people_venue_groups_on_venue_group_id_and_person_id"
  end

  create_table "rsvps", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "uniqid"
    t.integer "show_id"
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.string "phone_number"
    t.string "postcode"
    t.integer "seats"
    t.string "response"
    t.string "ip_address"
    t.string "confirmed"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmed"], name: "index_rsvps_on_confirmed"
    t.index ["email"], name: "index_rsvps_on_email"
    t.index ["response"], name: "index_rsvps_on_response"
    t.index ["show_id", "email"], name: "index_rsvps_on_show_id_and_email", unique: true
    t.index ["show_id"], name: "index_rsvps_on_show_id"
    t.index ["uniqid"], name: "index_rsvps_on_uniqid", unique: true
  end

  create_table "shows", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.datetime "start"
    t.datetime "end"
    t.string "name"
    t.string "slug"
    t.string "status"
    t.text "blurb"
    t.integer "price"
    t.integer "venue_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_shows_on_slug", unique: true
    t.index ["start"], name: "index_shows_on_start"
    t.index ["status"], name: "index_shows_on_status"
    t.index ["venue_id"], name: "index_shows_on_venue_id"
  end

  create_table "venue_groups", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "venue_groups_venues", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "venue_id", null: false
    t.integer "venue_group_id", null: false
    t.index ["venue_group_id", "venue_id"], name: "index_venue_groups_venues_on_venue_group_id_and_venue_id"
    t.index ["venue_id", "venue_group_id"], name: "index_venue_groups_venues_on_venue_id_and_venue_group_id"
  end

  create_table "venues", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "name"
    t.string "slug"
    t.string "address"
    t.string "city"
    t.string "province"
    t.string "postcode"
    t.string "country"
    t.integer "capacity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "directions"
    t.text "contact_info"
    t.index ["name"], name: "index_venues_on_name"
    t.index ["slug"], name: "index_venues_on_slug", unique: true
  end

  add_foreign_key "shows", "venues"
end

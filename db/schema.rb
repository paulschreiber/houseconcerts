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

ActiveRecord::Schema[7.2].define(version: 2025_02_21_200240) do
  create_table "active_storage_attachments", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", precision: nil, null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admins", charset: "utf8mb3", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true
  end

  create_table "artists", charset: "utf8mb3", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "name"
    t.string "slug"
    t.string "url"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["name"], name: "index_artists_on_name"
    t.index ["slug"], name: "index_artists_on_slug", unique: true
  end

  create_table "artists_shows", id: false, charset: "utf8mb3", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.bigint "artist_id", null: false
    t.bigint "show_id", null: false
    t.index ["artist_id", "show_id"], name: "index_artists_shows_on_artist_id_and_show_id"
    t.index ["show_id", "artist_id"], name: "index_artists_shows_on_show_id_and_artist_id"
  end

  create_table "friendly_id_slugs", charset: "utf8mb3", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "slug", null: false
    t.bigint "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at", precision: nil
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_id"
    t.index ["sluggable_type"], name: "index_friendly_id_slugs_on_sluggable_type"
  end

  create_table "opens", charset: "utf8mb3", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "tag"
    t.string "ip_address"
    t.string "email"
    t.boolean "open"
    t.boolean "click"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "people", charset: "utf8mb3", collation: "utf8_unicode_ci", force: :cascade do |t|
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
    t.datetime "removed_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["email"], name: "index_people_on_email", unique: true
    t.index ["first_name"], name: "index_people_on_first_name"
    t.index ["last_name"], name: "index_people_on_last_name"
    t.index ["status"], name: "index_people_on_status"
    t.index ["uniqid"], name: "index_people_on_uniqid", unique: true
  end

  create_table "people_venue_groups", id: false, charset: "utf8mb3", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.bigint "venue_group_id", null: false
    t.index ["person_id", "venue_group_id"], name: "index_people_venue_groups_on_person_id_and_venue_group_id"
    t.index ["venue_group_id", "person_id"], name: "index_people_venue_groups_on_venue_group_id_and_person_id"
  end

  create_table "rsvps", charset: "utf8mb3", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "uniqid"
    t.bigint "show_id"
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.string "phone_number"
    t.string "postcode"
    t.integer "seats"
    t.string "response"
    t.string "ip_address"
    t.string "confirmed"
    t.datetime "confirmed_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["confirmed"], name: "index_rsvps_on_confirmed"
    t.index ["email"], name: "index_rsvps_on_email"
    t.index ["response"], name: "index_rsvps_on_response"
    t.index ["show_id", "email"], name: "index_rsvps_on_show_id_and_email"
    t.index ["show_id"], name: "index_rsvps_on_show_id"
    t.index ["uniqid"], name: "index_rsvps_on_uniqid", unique: true
  end

  create_table "shows", charset: "utf8mb3", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.datetime "start", precision: nil
    t.datetime "end", precision: nil
    t.string "name"
    t.string "slug"
    t.string "status"
    t.text "blurb"
    t.integer "price"
    t.bigint "venue_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["slug"], name: "index_shows_on_slug", unique: true
    t.index ["start"], name: "index_shows_on_start"
    t.index ["status"], name: "index_shows_on_status"
    t.index ["venue_id"], name: "index_shows_on_venue_id"
  end

  create_table "venue_groups", charset: "utf8mb3", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "venue_groups_venues", id: false, charset: "utf8mb3", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.bigint "venue_id", null: false
    t.bigint "venue_group_id", null: false
    t.index ["venue_group_id", "venue_id"], name: "index_venue_groups_venues_on_venue_group_id_and_venue_id"
    t.index ["venue_id", "venue_group_id"], name: "index_venue_groups_venues_on_venue_id_and_venue_group_id"
  end

  create_table "venues", charset: "utf8mb3", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "name"
    t.string "slug"
    t.string "address"
    t.string "city"
    t.string "province"
    t.string "postcode"
    t.string "country"
    t.integer "capacity"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.text "directions"
    t.text "contact_info"
    t.index ["name"], name: "index_venues_on_name"
    t.index ["slug"], name: "index_venues_on_slug", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "shows", "venues"
end

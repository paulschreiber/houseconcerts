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

ActiveRecord::Schema[8.1].define(version: 2026_07_18_192930) do
  create_table "active_storage_attachments", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", precision: nil, null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admins", charset: "utf8mb3", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "last_sign_in_at", precision: nil
    t.string "last_sign_in_ip"
    t.datetime "remember_created_at", precision: nil
    t.datetime "reset_password_sent_at", precision: nil
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "webauthn_id"
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true
    t.index ["webauthn_id"], name: "index_admins_on_webauthn_id", unique: true
  end

  create_table "artists", charset: "utf8mb3", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "name"
    t.string "slug"
    t.datetime "updated_at", precision: nil, null: false
    t.string "url"
    t.index ["name"], name: "index_artists_on_name"
    t.index ["slug"], name: "index_artists_on_slug", unique: true
  end

  create_table "artists_shows", charset: "utf8mb3", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.bigint "artist_id", null: false
    t.bigint "show_id", null: false
    t.index ["artist_id", "show_id"], name: "index_artists_shows_on_artist_id_and_show_id"
    t.index ["show_id", "artist_id"], name: "index_artists_shows_on_show_id_and_artist_id"
  end

  create_table "friendly_id_slugs", charset: "utf8mb3", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.string "scope"
    t.string "slug", null: false
    t.bigint "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_id"
    t.index ["sluggable_type"], name: "index_friendly_id_slugs_on_sluggable_type"
  end

  create_table "opens", charset: "utf8mb3", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.boolean "click"
    t.datetime "created_at", precision: nil, null: false
    t.string "email"
    t.string "ip_address"
    t.boolean "open"
    t.string "tag"
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "people", charset: "utf8mb3", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "email"
    t.string "first_name"
    t.string "ip_address"
    t.string "last_name"
    t.string "notes"
    t.string "phone_number"
    t.string "postcode"
    t.string "removal_ip_address"
    t.datetime "removed_at", precision: nil
    t.string "status"
    t.string "uniqid"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["email"], name: "index_people_on_email", unique: true
    t.index ["first_name"], name: "index_people_on_first_name"
    t.index ["last_name"], name: "index_people_on_last_name"
    t.index ["status"], name: "index_people_on_status"
    t.index ["uniqid"], name: "index_people_on_uniqid", unique: true
  end

  create_table "people_venue_groups", charset: "utf8mb3", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.bigint "venue_group_id", null: false
    t.index ["person_id", "venue_group_id"], name: "index_people_venue_groups_on_person_id_and_venue_group_id"
    t.index ["venue_group_id", "person_id"], name: "index_people_venue_groups_on_venue_group_id_and_person_id"
  end

  create_table "rsvps", charset: "utf8mb3", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "confirmed"
    t.datetime "confirmed_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.string "email"
    t.string "first_name"
    t.string "ip_address"
    t.string "last_name"
    t.string "phone_number"
    t.string "postcode"
    t.string "referrer"
    t.string "response"
    t.integer "seats_reserved"
    t.integer "seats_used"
    t.bigint "show_id"
    t.string "uniqid"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["confirmed"], name: "index_rsvps_on_confirmed"
    t.index ["email"], name: "index_rsvps_on_email"
    t.index ["response"], name: "index_rsvps_on_response"
    t.index ["show_id", "email"], name: "index_rsvps_on_show_id_and_email"
    t.index ["show_id"], name: "index_rsvps_on_show_id"
    t.index ["uniqid"], name: "index_rsvps_on_uniqid", unique: true
  end

  create_table "shows", charset: "utf8mb3", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.text "blurb"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "end", precision: nil
    t.string "name"
    t.integer "price"
    t.string "slug"
    t.datetime "start", precision: nil
    t.string "status"
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "venue_id"
    t.index ["slug"], name: "index_shows_on_slug", unique: true
    t.index ["start"], name: "index_shows_on_start"
    t.index ["status"], name: "index_shows_on_status"
    t.index ["venue_id"], name: "index_shows_on_venue_id"
  end

  create_table "solid_cable_messages", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.binary "channel", limit: 1024, null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", size: :long, null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", limit: 1024, null: false
    t.bigint "key_hash", null: false
    t.binary "value", size: :long, null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "venue_groups", charset: "utf8mb3", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "name"
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "venue_groups_venues", charset: "utf8mb3", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.bigint "venue_group_id", null: false
    t.bigint "venue_id", null: false
    t.index ["venue_group_id", "venue_id"], name: "index_venue_groups_venues_on_venue_group_id_and_venue_id"
    t.index ["venue_id", "venue_group_id"], name: "index_venue_groups_venues_on_venue_id_and_venue_group_id"
  end

  create_table "venues", charset: "utf8mb3", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "address"
    t.integer "capacity"
    t.string "city"
    t.text "contact_info"
    t.string "country"
    t.datetime "created_at", precision: nil, null: false
    t.text "directions"
    t.string "name"
    t.string "postcode"
    t.string "province"
    t.string "slug"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["name"], name: "index_venues_on_name"
    t.index ["slug"], name: "index_venues_on_slug", unique: true
  end

  create_table "webauthn_credentials", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "admin_id", null: false
    t.integer "authentication_factor", limit: 1, null: false
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.string "name", null: false
    t.text "public_key", null: false
    t.bigint "sign_count", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_id"], name: "index_webauthn_credentials_on_admin_id"
    t.index ["external_id"], name: "index_webauthn_credentials_on_external_id", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "shows", "venues"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "webauthn_credentials", "admins"
end

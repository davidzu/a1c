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

ActiveRecord::Schema[8.1].define(version: 2026_09_23_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "doses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "kind", null: false
    t.integer "units", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_doses_on_created_at"
  end

  create_table "evidences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "note"
    t.bigint "submitter_id", null: false
    t.bigint "try_id", null: false
    t.datetime "updated_at", null: false
    t.index ["submitter_id"], name: "index_evidences_on_submitter_id"
    t.index ["try_id"], name: "index_evidences_on_try_id"
  end

  create_table "groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.text "description", default: "", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_groups_on_creator_id"
  end

  create_table "invite_codes", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_invite_codes_on_code", unique: true
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "group_id", null: false
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["group_id"], name: "index_memberships_on_group_id"
    t.index ["user_id", "group_id"], name: "index_memberships_on_user_id_and_group_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "missions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.text "description", null: false
    t.bigint "group_id", null: false
    t.bigint "speciality_id"
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_missions_on_creator_id"
    t.index ["group_id"], name: "index_missions_on_group_id"
    t.index ["speciality_id"], name: "index_missions_on_speciality_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["token"], name: "index_sessions_on_token", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "fast_name", default: "Fast", null: false
    t.decimal "last_a1c", precision: 3, scale: 1
    t.string "slow_name", default: "Slow", null: false
    t.datetime "updated_at", null: false
    t.decimal "weight_kg", precision: 5, scale: 2
  end

  create_table "specialities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", default: "", null: false
    t.bigint "group_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_specialities_on_group_id"
  end

  create_table "tries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "mission_id", null: false
    t.string "status", default: "in_progress", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["mission_id", "user_id"], name: "index_tries_on_mission_id_and_user_id", unique: true
    t.index ["mission_id"], name: "index_tries_on_mission_id"
    t.index ["user_id"], name: "index_tries_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.text "bio"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "evidences", "tries"
  add_foreign_key "evidences", "users", column: "submitter_id"
  add_foreign_key "groups", "users", column: "creator_id"
  add_foreign_key "memberships", "groups"
  add_foreign_key "memberships", "users"
  add_foreign_key "missions", "groups"
  add_foreign_key "missions", "specialities"
  add_foreign_key "missions", "users", column: "creator_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "specialities", "groups"
  add_foreign_key "tries", "missions"
  add_foreign_key "tries", "users"
end

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

ActiveRecord::Schema[8.1].define(version: 2026_09_29_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "a1c_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "measured_on", null: false
    t.datetime "updated_at", null: false
    t.decimal "value", precision: 3, scale: 1, null: false
    t.index ["measured_on"], name: "index_a1c_entries_on_measured_on", unique: true
  end

  create_table "activity_sessions", force: :cascade do |t|
    t.integer "avg_hr"
    t.integer "calories_kcal"
    t.string "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "ended_at", null: false
    t.integer "max_hr"
    t.integer "minutes", null: false
    t.string "source"
    t.datetime "started_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_activity_sessions_on_client_id", unique: true
    t.index ["started_at"], name: "index_activity_sessions_on_started_at"
  end

  create_table "doses", force: :cascade do |t|
    t.string "client_id"
    t.datetime "created_at", null: false
    t.integer "kind", null: false
    t.datetime "taken_at"
    t.integer "units", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_doses_on_client_id", unique: true
    t.index ["created_at"], name: "index_doses_on_created_at"
  end

  create_table "glucose_readings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "device"
    t.string "direction"
    t.integer "sgv", null: false
    t.datetime "time", null: false
    t.datetime "updated_at", null: false
    t.index ["time"], name: "index_glucose_readings_on_time", unique: true
  end

  create_table "nutrition_entries", force: :cascade do |t|
    t.integer "calories_kcal"
    t.integer "carbs_g"
    t.string "client_id", null: false
    t.datetime "created_at", null: false
    t.string "meal_type"
    t.string "source"
    t.datetime "taken_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_nutrition_entries_on_client_id", unique: true
    t.index ["taken_at"], name: "index_nutrition_entries_on_taken_at"
  end

  create_table "routes", force: :cascade do |t|
    t.integer "batch", null: false
    t.datetime "created_at", null: false
    t.float "distance_meters"
    t.datetime "ended_at"
    t.jsonb "points", default: [], null: false
    t.boolean "reached_target", default: false, null: false
    t.datetime "started_at"
    t.bigint "try_id", null: false
    t.datetime "updated_at", null: false
    t.index ["try_id", "batch"], name: "index_routes_on_try_id_and_batch", unique: true
    t.index ["try_id"], name: "index_routes_on_try_id"
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "fast_name", default: "Fast", null: false
    t.decimal "last_a1c", precision: 3, scale: 1
    t.string "slow_name", default: "Slow", null: false
    t.string "timezone", default: "America/Monterrey", null: false
    t.datetime "updated_at", null: false
    t.decimal "weight_kg", precision: 5, scale: 2
  end

  create_table "votes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "mission_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "value", null: false
    t.index ["mission_id"], name: "index_votes_on_mission_id"
    t.index ["user_id", "mission_id"], name: "index_votes_on_user_id_and_mission_id", unique: true
    t.index ["user_id"], name: "index_votes_on_user_id"
  end
end

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

ActiveRecord::Schema[8.1].define(version: 2026_09_27_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "fast_name", default: "Fast", null: false
    t.decimal "last_a1c", precision: 3, scale: 1
    t.string "slow_name", default: "Slow", null: false
    t.string "timezone", default: "America/Monterrey", null: false
    t.datetime "updated_at", null: false
    t.decimal "weight_kg", precision: 5, scale: 2
  end
end

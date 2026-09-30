class CreateActivityNutritionA1c < ActiveRecord::Migration[8.1]
  def change
    create_table :activity_sessions do |t|
      t.datetime :started_at, null: false
      t.datetime :ended_at, null: false
      t.integer :minutes, null: false
      t.integer :calories_kcal
      t.integer :avg_hr
      t.integer :max_hr
      t.string :source
      t.string :client_id, null: false

      t.timestamps

      t.index :client_id, unique: true
      t.index :started_at
    end

    create_table :nutrition_entries do |t|
      t.datetime :taken_at, null: false
      t.integer :carbs_g
      t.integer :calories_kcal
      t.string :meal_type
      t.string :source
      t.string :client_id, null: false

      t.timestamps

      t.index :client_id, unique: true
      t.index :taken_at
    end

    create_table :a1c_entries do |t|
      t.date :measured_on, null: false
      t.decimal :value, precision: 3, scale: 1, null: false

      t.timestamps

      t.index :measured_on, unique: true
    end
  end
end

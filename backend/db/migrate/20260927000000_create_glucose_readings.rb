class CreateGlucoseReadings < ActiveRecord::Migration[8.0]
  def change
    create_table :glucose_readings do |t|
      t.integer :sgv, null: false
      t.datetime :time, null: false
      t.string :direction
      t.string :device

      t.timestamps
    end
    add_index :glucose_readings, :time, unique: true
  end
end

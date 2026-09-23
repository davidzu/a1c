class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.string :fast_name, null: false, default: "Fast"
      t.string :slow_name, null: false, default: "Slow"
      t.decimal :weight_kg, precision: 5, scale: 2
      t.decimal :last_a1c, precision: 3, scale: 1

      t.timestamps
    end
  end
end

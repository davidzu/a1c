class WidenActivityNutritionToDecimal < ActiveRecord::Migration[8.0]
  # Health Connect payloads are fractional (Zepp wrote 53.4 g carbs,
  # 150.5 kcal) — the integer columns from the first slice-6 migration
  # rejected them with 422. Widen to decimal(9,2), matching weight_kg.
  def change
    change_column :activity_sessions, :calories_kcal, :decimal, precision: 9, scale: 2
    change_column :nutrition_entries, :calories_kcal, :decimal, precision: 9, scale: 2
    change_column :nutrition_entries, :carbs_g, :decimal, precision: 9, scale: 2
  end
end

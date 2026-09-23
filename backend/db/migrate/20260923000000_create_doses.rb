class CreateDoses < ActiveRecord::Migration[8.1]
  def change
    create_table :doses do |t|
      t.integer :units, null: false
      t.integer :kind, null: false

      t.timestamps
    end

    add_index :doses, :created_at
  end
end

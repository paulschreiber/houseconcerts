class CreateSettingValues < ActiveRecord::Migration[8.1]
  def change
    create_table :setting_values do |t|
      t.string :key, null: false
      t.text :value, null: false
      t.timestamps
    end
    add_index :setting_values, :key, unique: true
  end
end

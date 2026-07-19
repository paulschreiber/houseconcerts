class AddAvailabilityToShows < ActiveRecord::Migration[8.1]
  def change
    change_table :shows, bulk: true do |t|
      t.integer :availability, null: false, default: 0
      t.index :availability
    end
  end
end

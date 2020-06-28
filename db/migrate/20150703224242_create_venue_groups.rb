class CreateVenueGroups < ActiveRecord::Migration[4.2]
  def change
    create_table :venue_groups do |t|
      t.string :name

      t.timestamps null: false
    end
  end
end

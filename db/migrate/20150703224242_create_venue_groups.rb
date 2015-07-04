class CreateVenueGroups < ActiveRecord::Migration
  def change
    create_table :venue_groups do |t|
      t.string :name
      t.references :venue, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end

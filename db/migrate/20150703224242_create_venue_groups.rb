class CreateVenueGroups < ActiveRecord::Migration
  def change
    create_table :venue_groups do |t|

      t.timestamps null: false
    end
  end
end

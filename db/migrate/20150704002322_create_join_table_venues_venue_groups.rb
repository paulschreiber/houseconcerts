class CreateJoinTableVenuesVenueGroups < ActiveRecord::Migration
  def change
    create_join_table :venues, :venue_groups do |t|
      t.index [:venue_id, :venue_group_id]
      t.index [:venue_group_id, :venue_id]
    end
  end
end

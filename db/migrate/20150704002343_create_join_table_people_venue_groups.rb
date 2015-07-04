class CreateJoinTablePeopleVenueGroups < ActiveRecord::Migration
  def change
    create_join_table :people, :venue_groups do |t|
      t.index [:person_id, :venue_group_id]
      t.index [:venue_group_id, :person_id]
    end
  end
end

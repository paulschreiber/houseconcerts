class AddIdToVenueGroupsVenues < ActiveRecord::Migration[8.1]
  def change
    # rubocop:disable Rails/DangerousColumnNames -- backfilling a primary key onto an id: false HABTM join table
    add_column :venue_groups_venues, :id, :primary_key
    # rubocop:enable Rails/DangerousColumnNames
  end
end

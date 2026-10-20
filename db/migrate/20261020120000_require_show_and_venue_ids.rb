class RequireShowAndVenueIds < ActiveRecord::Migration[8.1]
  def change
    change_column_null :rsvps, :show_id, false
    change_column_null :shows, :venue_id, false
  end
end

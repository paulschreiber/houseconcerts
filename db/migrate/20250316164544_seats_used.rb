class SeatsUsed < ActiveRecord::Migration[7.2]
  def change
    rename_column :rsvps, :seats, :seats_reserved
    add_column :rsvp, :seats_used, :integer
  end
end

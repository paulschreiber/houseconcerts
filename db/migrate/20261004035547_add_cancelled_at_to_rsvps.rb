class AddCancelledAtToRsvps < ActiveRecord::Migration[8.1]
  def change
    add_column :rsvps, :cancelled_at, :datetime
  end
end

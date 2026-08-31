class AddAdminNotifiedAtToRsvps < ActiveRecord::Migration[8.1]
  def change
    add_column :rsvps, :admin_notified_at, :datetime
  end
end

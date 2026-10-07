class AddRespondedAtToRsvps < ActiveRecord::Migration[8.1]
  def change
    add_column :rsvps, :responded_at, :datetime

    # Approximate: switches to yes and seat changes aren't recorded anywhere,
    # and updated_at also moves for confirmations and emails.
    up_only do
      execute "UPDATE rsvps SET responded_at = COALESCE(cancelled_at, created_at)"
    end

    change_column_null :rsvps, :responded_at, false
  end
end

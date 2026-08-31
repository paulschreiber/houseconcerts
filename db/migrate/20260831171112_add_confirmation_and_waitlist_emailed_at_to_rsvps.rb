class AddConfirmationAndWaitlistEmailedAtToRsvps < ActiveRecord::Migration[8.1]
  def change
    change_table :rsvps, bulk: true do |t|
      t.column :confirmation_emailed_at, :datetime
      t.column :waitlist_emailed_at, :datetime
    end
  end
end

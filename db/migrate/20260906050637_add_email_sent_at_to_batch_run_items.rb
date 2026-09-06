class AddEmailSentAtToBatchRunItems < ActiveRecord::Migration[8.1]
  def change
    # Tracks the reminder email delivery separately from the item's
    # overall status, so a retry after an SMS-only failure doesn't
    # resend an email that already went out -- the two channels aren't
    # a single transactional operation.
    add_column :batch_run_items, :email_sent_at, :datetime
  end
end

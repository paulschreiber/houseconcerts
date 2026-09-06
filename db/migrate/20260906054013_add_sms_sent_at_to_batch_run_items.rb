class AddSmsSentAtToBatchRunItems < ActiveRecord::Migration[8.1]
  def change
    # Mirrors email_sent_at: marks SMS delivery independently so a retry
    # doesn't resend a text that already went out.
    add_column :batch_run_items, :sms_sent_at, :datetime
  end
end

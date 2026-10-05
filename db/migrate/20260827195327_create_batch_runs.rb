class CreateBatchRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :batch_runs do |t|
      t.references :show, null: false, foreign_key: true
      t.integer :kind, null: false
      t.integer :status, null: false, default: 0
      t.integer :total_count, null: false, default: 0
      t.integer :sent_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      # A partial unique index for MySQL: show+kind while a run is unfinished,
      # NULL once it completes (status 2), so only one unfinished run of a kind
      # per show can exist, but a new one can start after it finishes.
      t.virtual :active_kind_lock, type: :string,
                                   as: "(CASE WHEN status = 2 THEN NULL ELSE CONCAT(show_id, '-', kind) END)",
                                   stored: true

      t.timestamps

      t.index :active_kind_lock, unique: true
    end

    create_table :batch_run_items do |t|
      t.references :batch_run, null: false, foreign_key: true
      t.references :recipient, polymorphic: true, null: false
      t.integer :status, null: false, default: 0
      t.string :error_message
      t.datetime :sent_at
      # Per-channel delivery times, so a retry only re-sends the channel that
      # failed.
      t.datetime :email_sent_at
      t.datetime :sms_sent_at
      # BatchRunFanOutJob's claim, so two fan-outs can't enqueue the same item.
      t.datetime :fan_out_enqueued_at
      # Whether the item counts toward the run's sent/failed counts. Set when
      # the item is claimed; cleared when an admin retries a failed item.
      t.datetime :counted_at

      t.timestamps

      # One item per recipient, so a resumed fan-out can't duplicate one.
      t.index %i[batch_run_id recipient_type recipient_id],
              unique: true, name: "index_batch_run_items_on_batch_run_and_recipient"
    end
  end
end

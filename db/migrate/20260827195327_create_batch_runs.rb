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
      # A MySQL-compatible equivalent of a Postgres partial unique index:
      # NULL (multiple allowed) once a run completes (status = 2),
      # otherwise a show+kind key that can only exist once. This is what
      # stops two concurrent/duplicate runs of the same kind for the same
      # show from ever coexisting, while still allowing a fresh run of
      # that kind once the previous one has completed (e.g. sending a
      # second round of invites).
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
      # Tracks each channel's delivery independently from the item's
      # overall status, so a retry after a partial failure (e.g. email
      # sent, SMS raised) only re-attempts whichever channel didn't
      # already succeed -- the channels aren't a single transactional
      # operation.
      t.datetime :email_sent_at
      t.datetime :sms_sent_at

      t.timestamps

      # Lets a crashed-and-resumed BatchRunFanOutJob recompute recipients
      # and attempt to (re-)create an item for each one without risking a
      # duplicate: an already-existing item for the same recipient just
      # raises RecordNotUnique, which the job treats as "already done".
      t.index %i[batch_run_id recipient_type recipient_id],
              unique: true, name: "index_batch_run_items_on_batch_run_and_recipient"
    end
  end
end

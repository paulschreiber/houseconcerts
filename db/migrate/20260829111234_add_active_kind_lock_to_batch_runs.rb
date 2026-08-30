class AddActiveKindLockToBatchRuns < ActiveRecord::Migration[8.1]
  def change
    # A MySQL-compatible equivalent of a Postgres partial unique index: NULL
    # (multiple allowed) once a run completes (status = 2), otherwise a
    # show+kind key that can only exist once. This is what stops two
    # concurrent/duplicate runs of the same kind for the same show from ever
    # coexisting, while still allowing a fresh run of that kind once the
    # previous one has completed (e.g. sending a second round of invites).
    add_column :batch_runs, :active_kind_lock, :virtual,
               type: :string,
               as: "(CASE WHEN status = 2 THEN NULL ELSE CONCAT(show_id, '-', kind) END)",
               stored: true

    add_index :batch_runs, :active_kind_lock, unique: true
  end
end

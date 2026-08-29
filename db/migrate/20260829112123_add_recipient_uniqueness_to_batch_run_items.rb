class AddRecipientUniquenessToBatchRunItems < ActiveRecord::Migration[8.1]
  def change
    # Lets a crashed-and-resumed BatchRunFanOutJob recompute recipients and
    # attempt to (re-)create an item for each one without risking a
    # duplicate: an already-existing item for the same recipient just
    # raises RecordNotUnique, which the job treats as "already done".
    add_index :batch_run_items, [ :batch_run_id, :recipient_type, :recipient_id ],
              unique: true, name: "index_batch_run_items_on_batch_run_and_recipient"
  end
end

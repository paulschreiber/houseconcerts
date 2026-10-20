class AddCountedAtToBatchRunItemsStatusIndex < ActiveRecord::Migration[8.1]
  def change
    # BatchRun#recount_items groups a run's items by status and whether
    # counted_at is set, after every send; with counted_at in the index it's
    # counted from the index alone.
    remove_index :batch_run_items, [ :batch_run_id, :status ]
    add_index :batch_run_items, [ :batch_run_id, :status, :counted_at ], name: "index_batch_run_items_on_run_status_counted"
  end
end

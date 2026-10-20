class AddMissingIndexes < ActiveRecord::Migration[8.1]
  def change
    # Newest-first lists: the dashboard's recent opens, and the Opens and
    # RSVPs pages' default sort.
    add_index :opens, :created_at
    add_index :rsvps, :created_at
    # The dashboard's recent unsubscribes.
    add_index :people, [ :status, :removed_at ]
    # Matching an incoming text message to its sender's RSVP.
    add_index :rsvps, :phone_number
    # A batch run's progress counts and its failed or pending items.
    add_index :batch_run_items, [ :batch_run_id, :status ]

    # Covered by a multicolumn index that starts with the same column.
    remove_index :batch_run_items, :batch_run_id
    remove_index :rsvps, :show_id
    remove_index :people, :status
  end
end

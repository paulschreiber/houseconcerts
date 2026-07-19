class EnumsRename < ActiveRecord::Migration[8.0]
  # Not reversible: the string -> integer mapping below is lossy (e.g. "deleted" and
  # "vacation" both fold into the same "removed" value), so there's no way to
  # reconstruct the original strings on rollback.
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  def up
    change_table :rsvps, bulk: true do |t|
      t.rename :response, :old_response
      t.integer :response
      t.rename :confirmed, :old_confirmed
      t.integer :confirmed
    end

    change_table :shows, bulk: true do |t|
      t.rename :status, :old_status
      t.integer :status
    end

    change_table :people, bulk: true do |t|
      t.rename :status, :old_status
      t.integer :status
    end

    # enum :response, { no: 0, yes: 1 }
    response_map = { "no" => 0, "yes" => 1 }

    # enum :confirmed, { unconfirmed: 0, waitlisted: 1, yes: 2 }
    confirmed_map = { nil => 0, "waitlisted" => 1, "yes" => 2 }

    # enum :status, { confirmed: 0, unconfirmed: 1, cancelled: 2 }
    # "sold out" and "waitlisted" shows are still happening, so they fold into "confirmed"
    # for now; ticket availability will move to its own column in a follow-up.
    show_status_map = {
      "confirmed" => 0, "sold out" => 0, "waitlisted" => 0,
      "unconfirmed" => 1,
      "cancelled" => 2
    }

    # enum :status, { active: 0, bouncing: 1, moved: 2, removed: 3 }
    # "deleted" and "vacation" both fold into "removed"
    person_status_map = {
      "active" => 0, "bouncing" => 1, "moved" => 2,
      "removed" => 3, "deleted" => 3, "vacation" => 3
    }

    # update_columns skips callbacks and validations, which is what we want here:
    # a data migration shouldn't trigger RSVP's admin-notification emails, for example.
    # rubocop:disable Rails/SkipsModelValidations
    RSVP.find_each do |entry|
      entry.update_columns(
        response: response_map[entry.old_response],
        confirmed: confirmed_map[entry.old_confirmed]
      )
    end

    Show.find_each do |entry|
      entry.update_columns(status: show_status_map[entry.old_status])
    end

    Person.find_each do |entry|
      entry.update_columns(status: person_status_map[entry.old_status])
    end
    # rubocop:enable Rails/SkipsModelValidations

    change_table :rsvps, bulk: true do |t|
      t.index :response
      t.index :confirmed
      t.remove :old_response, type: :string
      t.remove :old_confirmed, type: :string
    end

    change_table :shows, bulk: true do |t|
      t.index :status
      t.remove :old_status, type: :string
    end

    change_table :people, bulk: true do |t|
      t.index :status
      t.remove :old_status, type: :string
    end
  end
end

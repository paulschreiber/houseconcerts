class EnumsRename < ActiveRecord::Migration[8.0]
  # Not reversible: the string -> integer mapping below is lossy (e.g. "deleted" and
  # "vacation" both fold into the same "removed" value), so there's no way to
  # reconstruct the original strings on rollback.
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  def up
    # Guarded so a crash partway through this migration (e.g. the NOT NULL
    # violation this migration used to hit during the backfill below) doesn't
    # leave an environment permanently stuck: re-running it finds the rename
    # already done and skips straight to the still-pending steps, instead of
    # failing again on now-mismatched column names.
    change_table :rsvps, bulk: true do |t|
      unless column_exists?(:rsvps, :old_response)
        t.rename :response, :old_response
        t.integer :response, null: false, default: 0
      end

      unless column_exists?(:rsvps, :old_confirmed)
        t.rename :confirmed, :old_confirmed
        t.integer :confirmed, null: false, default: 0
      end
    end

    change_table :shows, bulk: true do |t|
      unless column_exists?(:shows, :old_status)
        t.rename :status, :old_status
        t.integer :status, null: false, default: 0
      end
    end

    change_table :people, bulk: true do |t|
      unless column_exists?(:people, :old_status)
        t.rename :status, :old_status
        t.integer :status, null: false, default: 0
      end
    end

    # enum :response, { no: 0, yes: 1 }
    response_map = { "no" => 0, "yes" => 1 }

    # enum :confirmed, { unconfirmed: 0, waitlisted: 1, yes: 2 }
    confirmed_map = { nil => 0, "waitlisted" => 1, "yes" => 2 }

    # enum :status, { confirmed: 0, unconfirmed: 1, cancelled: 2 }
    # "sold out" and "waitlisted" shows are still happening, so they fold into "confirmed";
    # their original distinction is preserved via show_availability_map below.
    show_status_map = {
      "confirmed" => 0, "sold out" => 0, "waitlisted" => 0,
      "unconfirmed" => 1,
      "cancelled" => 2
    }

    # enum :availability, { available: 0, waitlisted: 1, sold_out: 2 }
    show_availability_map = {
      "waitlisted" => 1,
      "sold out" => 2
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
        response: response_map.fetch(entry.old_response, 0),
        confirmed: confirmed_map.fetch(entry.old_confirmed, 0)
      )
    end

    Show.find_each do |entry|
      entry.update_columns(
        status: show_status_map.fetch(entry.old_status, 0),
        availability: show_availability_map.fetch(entry.old_status, 0)
      )
    end

    Person.find_each do |entry|
      entry.update_columns(status: person_status_map.fetch(entry.old_status, 0))
    end
    # rubocop:enable Rails/SkipsModelValidations

    change_table :rsvps, bulk: true do |t|
      t.index :response unless index_exists?(:rsvps, :response)
      t.index :confirmed unless index_exists?(:rsvps, :confirmed)
      t.remove :old_response, type: :string if column_exists?(:rsvps, :old_response)
      t.remove :old_confirmed, type: :string if column_exists?(:rsvps, :old_confirmed)
    end

    change_table :shows, bulk: true do |t|
      t.index :status unless index_exists?(:shows, :status)
      t.remove :old_status, type: :string if column_exists?(:shows, :old_status)
    end

    change_table :people, bulk: true do |t|
      t.index :status unless index_exists?(:people, :status)
      t.remove :old_status, type: :string if column_exists?(:people, :old_status)
    end
  end
end

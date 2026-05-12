class EnumsRename < ActiveRecord::Migration[8.0]
  def change
    rename_column :rsvps, :response, :old_response
    add_column :rsvps, :response, :integer

    rename_column :rsvps, :confirmed, :old_confirmed
    add_column :rsvps, :confirmed, :integer

    rename_column :shows, :status, :old_status
    add_column :shows, :status, :integer

    rename_column :people, :status, :old_status
    add_column :people, :status, :integer

    # enum :response, { no: 0, maybe: 1, yes: 2 }
    # enum :confirmed, { no: 0, waitlised: 1, yes: 2 }
    response_array = %w(no maybe yes)
    confirmed_array = [nil, 'waitlisted', 'yes']
    RSVP.all.each do |entry|
      entry.response = response_array.index(entry.old_response)
      entry.confirmed = confirmed_array.index(entry.old_confirmed)
      entry.save(validate: false)
    end

    # enum :status, { confirmed: 0, pending: 1, cancelled: 2 }
    show_status_array = %w(confirmed pending cancelled)
    Show.all.each do |entry|
      entry.status = show_status_array.index(entry.old_status)
      entry.save(validate: false)
    end

    # enum :status, { active: 0, bouncing: 1, moved: 2, removed: 3 }
    person_status_array = %w(active bouncing moved removed)
    Person.all.each do |entry|
      entry.status = person_status_array.index(entry.old_status)
      entry.save(validate: false)
    end

    add_index :rsvps, :response
    add_index :rsvps, :confirmed
    add_index :shows, :status
    add_index :people, :status

    remove_column :rsvps, :old_response
    remove_column :rsvps, :old_confirmed
    remove_column :shows, :old_status
    remove_column :people, :old_status
  end
end

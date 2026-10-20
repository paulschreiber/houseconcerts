class SetSeatsOnLegacyYesRsvps < ActiveRecord::Migration[8.1]
  # Yes RSVPs imported from before this app (2005-2014) have 0 seats. They
  # get 1, the minimum a yes RSVP needs, so they pass validation and count as
  # attendance.
  def up
    updated = exec_update("UPDATE rsvps SET seats_reserved = 1 WHERE response = 1 AND (seats_reserved IS NULL OR seats_reserved < 1)")
    say "Set seats_reserved to 1 on #{updated} yes RSVPs"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

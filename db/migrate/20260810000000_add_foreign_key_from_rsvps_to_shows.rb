class AddForeignKeyFromRsvpsToShows < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :rsvps, :shows unless foreign_key_exists?(:rsvps, :shows)
  end
end

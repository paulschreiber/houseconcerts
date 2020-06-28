class AddRsvpsUniqueIndex < ActiveRecord::Migration[4.2]
  def change
    add_index :rsvps, [:show_id, :email], unique: true
  end
end

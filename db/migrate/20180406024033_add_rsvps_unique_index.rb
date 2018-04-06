class AddRsvpsUniqueIndex < ActiveRecord::Migration
  def change
    add_index :rsvps, [:show_id, :email], unique: true
  end
end

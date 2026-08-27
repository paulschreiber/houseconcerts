class AddUniqueIndexBackToRsvpsShowIdAndEmail < ActiveRecord::Migration[8.1]
  def change
    remove_index :rsvps, column: [:show_id, :email], name: "index_rsvps_on_show_id_and_email"
    add_index :rsvps, [:show_id, :email], unique: true, name: "index_rsvps_on_show_id_and_email"
  end
end

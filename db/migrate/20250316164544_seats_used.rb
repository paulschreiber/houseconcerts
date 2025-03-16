class SeatsUsed < ActiveRecord::Migration[7.2]
  def change
    change_table :rsvps, bulk: true do |t|
      t.rename :seats, :seats_reserved
      t.column :seats_used, :integer, after: :seats_reserved
    end
  end
end

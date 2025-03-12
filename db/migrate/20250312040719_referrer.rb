class Referrer < ActiveRecord::Migration[7.2]
  def change
    add_column :rsvps, :referrer, :string
  end
end

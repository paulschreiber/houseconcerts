class AddRSVPIP < ActiveRecord::Migration[4.2]
  def change
    add_column :rsvps, :ip_address, :string, after: :response
  end
end

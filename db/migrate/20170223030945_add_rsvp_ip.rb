class AddRSVPIp < ActiveRecord::Migration
  def change
    add_column :rsvps, :ip_address, :string, after: :response
  end
end

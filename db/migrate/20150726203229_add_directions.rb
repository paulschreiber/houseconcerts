class AddDirections < ActiveRecord::Migration[4.2]
  def change
    add_column :venues, :directions, :text
    add_column :venues, :contact_info, :text

  end
end

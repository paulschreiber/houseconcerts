class AddActiveToVenues < ActiveRecord::Migration[8.1]
  def change
    add_column :venues, :active, :boolean, default: true, null: false
  end
end

class CreateVenues < ActiveRecord::Migration
  def change
    create_table :venues do |t|
      t.string :name
      t.string :address
      t.string :city
      t.string :province
      t.string :postcode
      t.string :country
      t.integer :capacity
      t.string :slug

      t.timestamps null: false
    end
    add_index :venues, :name
    add_index :venues, :slug, unique: true
  end
end

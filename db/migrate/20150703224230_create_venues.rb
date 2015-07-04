class CreateVenues < ActiveRecord::Migration
  def change
    create_table :venues do |t|
      t.string :name
      t.string :slug
      t.string :address
      t.string :city
      t.string :province
      t.string :postcode
      t.string :country
      t.integer :capacity

      t.timestamps null: false

      t.index :name
      t.index :slug, unique: true
    end
  end
end

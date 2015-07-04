class CreateShows < ActiveRecord::Migration
  def change
    create_table :shows do |t|
      t.datetime :start
      t.datetime :end
      t.string :slug
      t.string :status
      t.text :blurb
      t.integer :price
      t.references :venue, index: true, foreign_key: true

      t.timestamps null: false

      t.index :slug, unique: true
      t.index :start
      t.index :status
    end
  end
end

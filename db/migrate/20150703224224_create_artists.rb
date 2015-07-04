class CreateArtists < ActiveRecord::Migration
  def change
    create_table :artists do |t|
      t.string :name
      t.string :slug
      t.string :url

      t.timestamps null: false
    end
    add_index :artists, :name
    add_index :artists, :slug, unique: true
  end
end

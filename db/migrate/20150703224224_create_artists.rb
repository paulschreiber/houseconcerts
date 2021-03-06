class CreateArtists < ActiveRecord::Migration[4.2]
  def change
    create_table :artists do |t|
      t.string :name
      t.string :slug
      t.string :url

      t.timestamps null: false

      t.index :name
      t.index :slug, unique: true
    end
  end
end

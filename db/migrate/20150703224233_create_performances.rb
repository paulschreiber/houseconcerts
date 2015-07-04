class CreatePerformances < ActiveRecord::Migration
  def change
    create_table :performances do |t|
      t.references :show, index: true, foreign_key: true
      t.references :artist, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end

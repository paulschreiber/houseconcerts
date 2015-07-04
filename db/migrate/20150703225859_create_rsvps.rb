class CreateRsvps < ActiveRecord::Migration
  def change
    create_table :rsvps do |t|
      t.references :show, index: true, foreign_key: true
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :postcode
      t.integer :seats
      t.string :response
      t.string :confirmed
      t.datetime :confirmed_at

      t.timestamps null: false

      t.index :email
      t.index :response
      t.index :confirmed
    end
  end
end

class CreatePeople < ActiveRecord::Migration[4.2]
  def change
    create_table :people do |t|
      t.string :uniqid
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :postcode
      t.string :notes
      t.string :status
      t.string :ip_address
      t.string :removal_ip_address
      t.datetime :removed_at

      t.timestamps null: false

      t.index :uniqid, unique: true
      t.index :first_name
      t.index :last_name
      t.index :email, unique: true
      t.index :status
    end
  end
end

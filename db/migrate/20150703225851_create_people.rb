class CreatePeople < ActiveRecord::Migration
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
    end
    add_index :people, :uniqid, unique: true
    add_index :people, :first_name
    add_index :people, :last_name
    add_index :people, :email
    add_index :people, :status
  end
end

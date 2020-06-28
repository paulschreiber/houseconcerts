class CreateOpens < ActiveRecord::Migration[4.2]
  def change
    create_table :opens do |t|
      t.string :tag
      t.string :ip_address
      t.string :email
      t.boolean :open
      t.boolean :click
      t.timestamps null: false
    end
  end
end

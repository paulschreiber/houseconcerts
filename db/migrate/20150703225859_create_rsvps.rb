class CreateRsvps < ActiveRecord::Migration
  def change
    create_table :rsvps do |t|

      t.timestamps null: false
    end
  end
end

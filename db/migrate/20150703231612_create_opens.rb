class CreateOpens < ActiveRecord::Migration
  def change
    create_table :opens do |t|

      t.timestamps null: false
    end
  end
end

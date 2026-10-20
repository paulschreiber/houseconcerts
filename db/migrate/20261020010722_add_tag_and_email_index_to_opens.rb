class AddTagAndEmailIndexToOpens < ActiveRecord::Migration[8.1]
  def change
    add_index :opens, [ :tag, :email ]
  end
end

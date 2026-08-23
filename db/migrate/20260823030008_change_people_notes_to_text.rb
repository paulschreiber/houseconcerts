class ChangePeopleNotesToText < ActiveRecord::Migration[8.1]
  def change
    change_column :people, :notes, :text, size: :medium
  end
end

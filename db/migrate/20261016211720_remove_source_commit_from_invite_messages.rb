class RemoveSourceCommitFromInviteMessages < ActiveRecord::Migration[8.1]
  def change
    change_table :invite_messages, bulk: true do |t|
      t.remove_index :source_commit, unique: true
      t.remove :source_commit, type: :string
    end
  end
end

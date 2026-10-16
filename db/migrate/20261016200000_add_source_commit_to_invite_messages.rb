# The git commit each imported invite revision came from, so the one-time
# history import can skip what it has already saved.
class AddSourceCommitToInviteMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :invite_messages, :source_commit, :string
    add_index :invite_messages, :source_commit, unique: true
  end
end

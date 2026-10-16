# When a revision was sent before the invite editor existed: past invites
# imported from git history have no batch to show they went out. Revisions
# already imported are marked sent as of their commit date (their created_at).
# source_commit is gone once the import is removed, and then there's nothing
# to mark.
class AddSentAtToInviteMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :invite_messages, :sent_at, :datetime

    up_only do
      execute "UPDATE invite_messages SET sent_at = created_at WHERE source_commit IS NOT NULL" if column_exists?(:invite_messages, :source_commit)
    end
  end
end

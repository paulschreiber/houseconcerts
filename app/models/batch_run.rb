class BatchRun < ApplicationRecord
  belongs_to :show
  has_many :batch_run_items, dependent: :destroy

  enum :kind, { invite: 0, invite_unopened: 1, remind: 2 }
  enum :status, { pending: 0, running: 1, completed: 2 }, default: :pending

  KIND_LABELS = {
    "invite" => "Invites",
    "invite_unopened" => "Unopened invites",
    "remind" => "Reminders"
  }.freeze

  def self.kind_label(kind) = KIND_LABELS.fetch(kind.to_s)

  def processed_count
    sent_count + failed_count
  end
end

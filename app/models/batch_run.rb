class BatchRun < ApplicationRecord
  belongs_to :show
  has_many :batch_run_items, dependent: :destroy

  enum :kind, { invite: 0, invite_unopened: 1, remind: 2 }
  enum :status, { pending: 0, running: 1, completed: 2 }, default: :pending

  # Each kind's label, its button on the show page, how it's described in
  # messages, and whether initial invites must have gone out first.
  KINDS = {
    "invite" => { label: "Invites", button: "Send Invites", description: "invites", requires_invites_sent: false },
    "invite_unopened" => { label: "Unopened invites", button: "Send to Unopened", description: "invites to unopened recipients",
                           requires_invites_sent: true },
    "remind" => { label: "Reminders", button: "Send Reminders", description: "reminders", requires_invites_sent: true }
  }.freeze

  # Runs that finished and sent at least one message. A run cancelled before
  # sending, or one where every send failed, is also "completed".
  scope :delivered, -> { completed.where(sent_count: 1..) }

  def self.kind_label(kind) = KINDS.fetch(kind.to_s)[:label]

  def self.kind_description(kind) = KINDS.fetch(kind.to_s)[:description]

  def self.requires_invites_sent?(kind) = KINDS.fetch(kind.to_s)[:requires_invites_sent]

  def processed_count
    sent_count + failed_count
  end

  # Shared by every place that changes a batch_run's visible state
  # (BatchRunItemJob, BatchRunFanOutJob, Madmin::ShowsController#cancel_batch_run):
  # broadcasting from one place, rather than duplicating this call at
  # each site, is what keeps them from drifting -- cancel_batch_run once
  # didn't broadcast at all, leaving any other admin with the show page
  # open still looking at "Running" until they refreshed.
  def broadcast_progress
    Turbo::StreamsChannel.broadcast_replace_to(
      [ show, :batch_progress ],
      target: "batch_run_progress_#{kind}",
      partial: "madmin/shows/batch_run_progress",
      locals: { batch_run: self }
    )
  end
end

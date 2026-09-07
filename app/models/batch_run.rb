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

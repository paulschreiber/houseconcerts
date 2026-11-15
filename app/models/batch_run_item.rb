class BatchRunItem < ApplicationRecord
  belongs_to :batch_run
  belongs_to :recipient, polymorphic: true

  # "cancelled" is deliberately excluded from BatchRunItemJob::CLAIMABLE_STATUSES:
  # it marks an item that will never be attempted because an admin
  # cancelled the run, or that BatchRunItemJob skipped as no longer wanted
  # (SkippedRecipient) -- not a failure to retry, so it must never be
  # reclaimable by a job that's already enqueued for it (or a stray
  # redelivery) once the run's been cancelled.
  enum :status, { pending: 0, sent: 1, failed: 2, cancelled: 3 }, default: :pending

  # Sent invites to people (batch invites, not single InvitePerson ones,
  # which aren't recorded) for the show.
  def self.person_invites_for(show)
    sent.where(recipient_type: "Person")
        .joins(:batch_run)
        .where(batch_runs: { show_id: show, kind: %w[invite invite_unopened] })
  end
end

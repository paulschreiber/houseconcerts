class BatchRunItem < ApplicationRecord
  belongs_to :batch_run
  belongs_to :recipient, polymorphic: true

  # "cancelled" is deliberately excluded from BatchRunItemJob::CLAIMABLE_STATUSES:
  # it marks an item that will never be attempted because an admin
  # cancelled the run, not a failure to retry, so it must never be
  # reclaimable by a job that's already enqueued for it (or a stray
  # redelivery) once the run's been cancelled.
  enum :status, { pending: 0, sent: 1, failed: 2, cancelled: 3 }, default: :pending
end

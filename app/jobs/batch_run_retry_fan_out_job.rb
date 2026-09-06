class BatchRunRetryFanOutJob < ApplicationJob
  # Enqueues a BatchRunItemJob for every currently-failed item on a
  # reopened run. Kept as its own job (rather than looping inline in the
  # controller) so a crash partway through -- e.g. after 37 of 100 items
  # got enqueued -- doesn't strand the rest: Solid Queue redelivers this
  # job, and it just re-scans batch_run_items for whatever's still
  # "failed" rather than relying on anything from the previous attempt.
  # That scan is by individual item status, not the run's aggregate
  # failed_count (which the controller already reset to 0 before
  # enqueuing this job), so a partial previous attempt can't hide
  # still-failed items from it.
  def perform(batch_run_id)
    BatchRun.find(batch_run_id).batch_run_items.failed.find_each { |item| BatchRunItemJob.perform_later(item.id) }
  end
end

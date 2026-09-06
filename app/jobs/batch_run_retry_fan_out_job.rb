class BatchRunRetryFanOutJob < ApplicationJob
  # Without this, a transient error raised mid-loop (e.g. enqueuing item
  # #37 of 100) would fail this job with nothing left to finish it. An
  # admin re-clicking "Retry" would still recover (the button and gate
  # query live batch_run_items.failed, not this run's aggregate counter),
  # but retrying automatically means that doesn't have to depend on an
  # admin noticing and acting -- and re-running perform in full is always
  # safe here, per the resumability described below.
  #
  # Scoped to ActiveRecord::AdapterError (connection drops, deadlocks,
  # lock/statement timeouts) plus SolidQueue::Job::EnqueueError -- which
  # is what a transient DB problem during perform_later actually surfaces
  # as, since Solid Queue's Job.enqueue rescues
  # ActiveRecord::ActiveRecordError and re-raises it wrapped in that
  # class instead. Not bare StandardError, so a real bug gets surfaced
  # immediately instead of retried 5 times against something that can
  # never resolve itself.
  retry_on ActiveRecord::AdapterError, SolidQueue::Job::EnqueueError, wait: :polynomially_longer, attempts: 5

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

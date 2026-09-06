class BatchRunRetryFanOutJob < ApplicationJob
  include ClaimsBatchRunItemsForEnqueue

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
  # Claimed via the same fan_out_enqueued_at column BatchRunFanOutJob
  # uses (reset to NULL by Madmin::ShowsController#retry_failed_batch_run
  # alongside failed_count/counted_at), for the same reason: without a
  # claim, a double-clicked "Retry" -- or this job simply being
  # redelivered after already enqueuing some items -- could enqueue two
  # BatchRunItemJobs for the same failed item. That's not just a
  # harmless duplicate: if both actually run, the second one reclaims
  # the item (still "failed" is claimable) and re-sends it, and
  # whichever of the two resolves second finds counted_at already set
  # by the first and silently never gets counted, undercounting the run
  # forever despite having genuinely just sent something. See
  # ClaimsBatchRunItemsForEnqueue for the claim itself, including why a
  # stale one is still reclaimable (a worker dying between claiming an
  # item here and actually enqueuing it leaves nothing to redeliver).
  def perform(batch_run_id)
    batch_run = BatchRun.find(batch_run_id)
    claimable(batch_run.batch_run_items.failed).find_each { |item| enqueue_item(item) }
  end
end

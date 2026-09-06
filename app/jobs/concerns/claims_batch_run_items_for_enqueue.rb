# Shared by BatchRunFanOutJob and BatchRunRetryFanOutJob: both enqueue a
# BatchRunItemJob per item, and both need the same atomic per-item claim
# (fan_out_enqueued_at) first, so two executions racing over the same
# items -- including one of these two job classes against the other,
# since they can both be enqueueing for the same batch_run's items at
# once -- can't both enqueue a job for the same one. Living in one
# place, not copy-pasted into each job, is what keeps the staleness
# handling in sync between them: it drifted out of sync once already,
# when BatchRunRetryFanOutJob's own version of this was added without
# picking up STRANDED_CLAIM_AGE.
module ClaimsBatchRunItemsForEnqueue
  extend ActiveSupport::Concern

  # How long a claim is trusted before it's treated as abandoned. A
  # crash between claiming an item (setting fan_out_enqueued_at) and
  # actually calling perform_later for it right after (process kill,
  # OOM -- not a raised exception, which the rescue below already
  # handles) leaves an item claimed but never actually enqueued, with
  # nothing to redeliver: no BatchRunItemJob was ever created to retry.
  # Set high enough that it can never fire against an item that's
  # merely still being *sent* by a genuinely in-flight job (a live
  # mail/SMS delivery taking a while) -- the gap a claim actually needs
  # to survive is the single method call between the two lines below,
  # not the send itself.
  STRANDED_CLAIM_AGE = 10.minutes

  private

    def claimable(scope)
      scope.where("fan_out_enqueued_at IS NULL OR fan_out_enqueued_at < ?", STRANDED_CLAIM_AGE.ago)
    end

    # Claims a single item (atomically) before enqueuing a job for it.
    # A duplicate enqueue of a still-pending item is harmless on its own
    # (BatchRunItemJob's own claim makes the second one a no-op), but if
    # the first duplicate's send fails, the item becomes "failed" -- a
    # status deliberately left reclaimable for admin retries -- so an
    # unclaimed second duplicate could then resend it automatically. If
    # perform_later itself raises, the claim is released so a later
    # attempt doesn't skip the item forever.
    def enqueue_item(item)
      claimed = claimable(BatchRunItem.where(id: item.id))
                .update_all(fan_out_enqueued_at: Time.current) == 1 # rubocop:disable Rails/SkipsModelValidations
      return unless claimed

      begin
        BatchRunItemJob.perform_later(item.id)
      rescue StandardError
        BatchRunItem.where(id: item.id).update_all(fan_out_enqueued_at: nil) # rubocop:disable Rails/SkipsModelValidations
        raise
      end
    end
end

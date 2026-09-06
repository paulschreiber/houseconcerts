class BatchRunFanOutJob < ApplicationJob
  # Without this, an exception raised mid-run (e.g. a transient DB error
  # while creating an item or enqueuing a BatchRunItemJob) would fail this
  # job with nothing left to ever finish it: the run would stay "running"
  # with some items never enqueued, and neither StartBatchRun's resume
  # logic (which only resumes "pending" runs) nor active_kind_lock (which
  # blocks starting a fresh one) provide a way out. Safe to retry in full
  # regardless of where it died, per the resumability described below.
  #
  # Scoped to two things, not bare StandardError -- a real bug
  # (NoMethodError, an unknown kind, a bad query) would just get retried
  # 5 times against something that can never resolve itself before
  # finally surfacing:
  # - ActiveRecord::AdapterError, "Superclass for all errors raised from
  #   an Active Record adapter" (connection drops, deadlocks,
  #   lock/statement timeouts), for this job's own direct DB operations.
  # - SolidQueue::Job::EnqueueError, which is what a transient DB problem
  #   during BatchRunItemJob.perform_later actually surfaces as: Solid
  #   Queue's Job.enqueue rescues ActiveRecord::ActiveRecordError and
  #   re-raises it wrapped in this class (a plain StandardError, not an
  #   AdapterError), so retry_on ActiveRecord::AdapterError alone never
  #   actually catches an enqueue failure despite that being the
  #   motivating case above.
  retry_on ActiveRecord::AdapterError, SolidQueue::Job::EnqueueError, wait: :polynomially_longer, attempts: 5

  # Populates a BatchRun's items and enqueues their per-item jobs. Kept
  # separate from StartBatchRun (which just creates the BatchRun row) so
  # this slow part -- computing recipients and doing up to one insert +
  # one enqueue per recipient -- runs in the background instead of
  # blocking the admin's request.
  #
  # Resumable: if this job dies partway through (worker crash, deploy,
  # reboot) and Solid Queue redelivers it, recipients are recomputed and
  # re-attempted, but an item that already exists for a given recipient
  # (per the unique index on batch_run_items) is simply skipped rather
  # than duplicated. total_count is only set once, after every recipient
  # has been attempted, and per-item jobs are only enqueued after that --
  # so a job that's already running can't see a stale/incomplete count
  # and mark the run "completed" too early.
  #
  # Resumption isn't limited to the item-creation phase: if the job dies
  # after status is already flipped to "running" but before every item
  # got enqueued, a redelivery skips straight to re-enqueuing whatever's
  # still pending -- it does not bail out just because status is no
  # longer "pending". That's safe to do unconditionally (even on a
  # non-crash redelivery) because BatchRunItemJob's claim step makes a
  # duplicate enqueue of an already-sent item a no-op.
  def perform(batch_run_id)
    batch_run = BatchRun.find(batch_run_id)
    return if batch_run.completed?

    if batch_run.pending?
      # Atomic claim, not just a pending? boolean check: StartBatchRun's
      # resume logic can enqueue a second fan-out job for the same
      # pending run while a first one is still mid-flight (e.g. an admin
      # re-triggering a send before the original job has finished
      # computing recipients). Without this, both executions could pass
      # the pending? check, independently create items and each compute
      # their own total_count, and race setting status/total_count --
      # the run's correctness depends on only one execution ever doing
      # this phase. update_all here only succeeds for whichever
      # execution gets there first; the loser falls through to the
      # final re-scan below, same as any other resumed execution.
      claimed = BatchRun.where(id: batch_run_id, status: "pending")
                        .update_all(status: "running", started_at: Time.current) == 1 # rubocop:disable Rails/SkipsModelValidations

      if claimed
        recipients_for(batch_run).each do |recipient|
          batch_run.batch_run_items.create!(recipient: recipient, status: :pending)
        rescue ActiveRecord::RecordNotUnique
          next
        end

        total_count = batch_run.batch_run_items.count
        batch_run.update!(total_count: total_count)

        if total_count.zero?
          batch_run.update!(status: :completed, completed_at: Time.current)
          return
        end
      end
    end

    batch_run.batch_run_items.pending.find_each { |item| BatchRunItemJob.perform_later(item.id) }
  end

  private

    def recipients_for(batch_run)
      show = batch_run.show

      case batch_run.kind
      when "invite"
        invite_recipients(show)
      when "invite_unopened"
        invite_recipients(show).where(
          "NOT EXISTS (SELECT 1 FROM opens WHERE opens.tag LIKE ? AND opens.email = people.email)",
          "#{show.slug}:invite%"
        )
      when "remind"
        show.attendees
      else
        raise ArgumentError, "unknown batch run kind: #{batch_run.kind}"
      end
    end

    def invite_recipients(show)
      Person.includes(:venue_groups)
            .where(venue_groups: { id: Settings.default_venue_group }, status: "active")
            .where(
              "NOT EXISTS (SELECT 1 FROM rsvps WHERE rsvps.show_id = ? AND rsvps.email = people.email)",
              show.id
            )
            .order(:last_name, :first_name)
    end
end

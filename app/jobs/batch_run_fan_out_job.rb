class BatchRunFanOutJob < ApplicationJob
  include ClaimsBatchRunItemsForEnqueue

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
  # than duplicated. Status only flips to "running" (and total_count only
  # gets set) after every recipient has been attempted -- not before --
  # so a job that's already running can't see a stale/incomplete count
  # and mark the run "completed" too early.
  #
  # The whole recipient-creation/total_count phase runs inside
  # batch_run.with_lock: StartBatchRun's resume logic can enqueue a
  # second fan-out job for the same pending run while a first one is
  # still mid-flight (e.g. an admin re-triggering a send before the
  # original job finished computing recipients), and without a real
  # mutual-exclusion lock, both executions could interleave -- one
  # racing ahead to enqueue per-item jobs against a total_count that's
  # still 0, completing the run before the other has finished creating
  # every recipient. with_lock (SELECT ... FOR UPDATE) makes a second,
  # truly concurrent execution block until the first's transaction
  # commits or rolls back, rather than observe a half-finished snapshot.
  # If the winner dies before committing, the whole transaction rolls
  # back -- no partial items, status still "pending" -- so a later
  # attempt (this same execution retried, or a blocked second one
  # resuming) redoes the entire phase from scratch, safely deduped.
  def perform(batch_run_id)
    batch_run = BatchRun.find(batch_run_id)
    return if batch_run.completed?

    transitioned = false

    batch_run.with_lock do
      next unless batch_run.pending?

      recipients_for(batch_run).each do |recipient|
        batch_run.batch_run_items.create!(recipient: recipient, status: :pending)
      rescue ActiveRecord::RecordNotUnique
        next
      end

      total_count = batch_run.batch_run_items.count

      if total_count.zero?
        batch_run.update!(status: :completed, total_count: total_count, completed_at: Time.current)
      else
        batch_run.update!(status: :running, total_count: total_count, started_at: Time.current)
      end

      transitioned = true
    end

    # Without this, the show page would sit on "Not sent yet" until
    # something else broadcasts -- which, for a run with zero eligible
    # recipients, never happens at all (no BatchRunItemJob is ever
    # enqueued to do it), and even for a normal run, leaves it looking
    # untouched until the first item resolves. Only fires once, right
    # after the transition actually committed above (not on a call that
    # found the run already past "pending" and skipped straight to
    # enqueueing) -- broadcasting an uncommitted or unchanged state would
    # be either wrong or just noise.
    batch_run.broadcast_progress if transitioned

    return if batch_run.completed?

    enqueue_pending_items(batch_run)
  end

  private

    # Two fan-out executions can both reach here (e.g. one that just
    # finished the snapshot, and another that lost the with_lock race
    # and fell through with nothing left to do there) -- see
    # ClaimsBatchRunItemsForEnqueue for why each item still needs its
    # own claim before being enqueued.
    def enqueue_pending_items(batch_run)
      claimable(batch_run.batch_run_items.pending).find_each { |item| enqueue_item(item) }
    end

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

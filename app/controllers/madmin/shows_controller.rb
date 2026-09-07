module Madmin
  class ShowsController < Madmin::ResourceController
    before_action { Current.admin_scope = params[:scope] }

    def send_invites
      start_batch_run("invite", "invites")
    end

    def send_invites_unopened
      start_batch_run("invite_unopened", "invites to unopened recipients", require_invites_sent: true)
    end

    def send_reminders
      start_batch_run("remind", "reminders", require_invites_sent: true)
    end

    def retry_failed_batch_run
      # Keyed on the specific batch_run, not "the latest run of this
      # kind" -- once a newer run of the same kind exists, that lookup
      # would silently point at the wrong (newer, possibly failure-free)
      # run and strand this run's failures with no way to retry them.
      batch_run = @record.batch_runs.find_by(id: params.require(:batch_run_id))
      kind_label = batch_run ? BatchRun.kind_label(batch_run.kind).downcase : "batch"
      # Queried live, not read off any cached counter: if a previous
      # retry's own enqueue failed partway through, this still sees
      # whatever's genuinely still "failed" and lets retrying again --
      # instead of silently stranding some of them forever.
      failed_items = batch_run&.batch_run_items&.failed

      if batch_run.nil? || failed_items.none?
        redirect_back_or_to resource.show_path(@record), alert: "There are no failed #{kind_label} sends to retry."
        return
      end

      retry_count = failed_items.count
      kind = batch_run.kind

      # Reopen the run so its progress bar shows again while the retries
      # are in flight. Conditioned on status still matching what was
      # read above, not a blind write: without this, a concurrent
      # cancel_batch_run completing the run between that read and this
      # write would get silently overwritten back to "running" --
      # reopening, and then actually retrying, a batch the admin had
      # just cancelled.
      begin
        reopened = BatchRun.where(id: batch_run.id, status: batch_run.status)
                           .update_all(status: BatchRun.statuses[:running], completed_at: nil) == 1 # rubocop:disable Rails/SkipsModelValidations
      rescue ActiveRecord::RecordNotUnique
        # active_kind_lock only allows one non-completed run per show+kind
        # at a time -- reopening this (older) run collides if a newer run
        # of the same kind is currently pending/running.
        redirect_back_or_to resource.show_path(@record),
                            alert: "Can't retry right now -- a newer #{kind_label} batch is already in progress for #{@record.name}. Try again once it finishes."
        return
      end

      unless reopened
        redirect_back_or_to resource.show_path(@record),
                            alert: "Can't retry right now -- this #{kind_label} batch's status just changed (it may have been cancelled). Please check and try again."
        return
      end

      # Deliberately left "failed", not reset to "pending": if
      # BatchRunFanOutJob.perform_later below itself fails to enqueue,
      # these items staying "failed" is what lets the retry button/gate
      # (which query .failed) find and offer them again on a later
      # click. counted_at is reset so BatchRunItemJob#record_progress's
      # live recount excludes them until they actually resolve again --
      # without it, processed_count would already equal total_count the
      # instant the run reopens, before any retry has run.
      # fan_out_enqueued_at is reset alongside it since it's still set
      # from their first, now-failed attempt.
      failed_items.update_all(counted_at: nil, fan_out_enqueued_at: nil) # rubocop:disable Rails/SkipsModelValidations

      # Handed off to BatchRunFanOutJob -- not a separate retry-specific
      # job -- so a crash partway through enqueuing doesn't strand the
      # remaining failed items: its own pending? guard already skips the
      # recipient-snapshot phase for a non-"pending" run and falls
      # straight through to re-scanning for unresolved items, which
      # includes these (see its own comment for why "failed" is in that
      # scan at all).
      begin
        BatchRunFanOutJob.perform_later(batch_run.id)
      rescue ActiveRecord::AdapterError, SolidQueue::Job::EnqueueError
        # Solid Queue raises synchronously, at the point perform_later is
        # called, not later in a worker -- so a transient DB problem here
        # would otherwise surface as a raw 500. The run itself is fine
        # (failed_items are still "failed" and untouched otherwise), so
        # clicking Retry again picks up right where this left off -- the
        # button/gate query the real items, not a cached counter.
        redirect_back_or_to resource.show_path(@record), alert: "Couldn't start retrying #{kind_label} sends right now -- please try again in a moment."
        return
      end

      redirect_back_or_to resource.show_path(@record), notice: "Retrying #{retry_count} failed #{BatchRun.kind_label(kind).downcase} for #{@record.name}."
    end

    # An escape hatch for a run that's stuck, or that an admin simply
    # wants to stop -- neither StartBatchRun's resume logic (only
    # "pending" runs) nor retry_failed_batch_run (only runs with failed
    # items) can unblock a run that's "running" with no failures, and
    # active_kind_lock otherwise blocks starting a fresh one of this
    # kind for this show until it does reach completed.
    def cancel_batch_run
      batch_run = @record.batch_runs.find_by(id: params.require(:batch_run_id))
      kind_label = batch_run ? BatchRun.kind_label(batch_run.kind).downcase : "batch"

      if batch_run.nil? || batch_run.completed?
        redirect_back_or_to resource.show_path(@record), alert: "There is no in-progress #{kind_label} batch to cancel."
        return
      end

      # Any item still pending is marked "cancelled", not left as-is:
      # that status is deliberately excluded from
      # BatchRunItemJob::CLAIMABLE_STATUSES, so a job that's already
      # enqueued for one -- cancelling can't un-enqueue a Solid Queue
      # job -- finds nothing claimable and never sends it. Items that
      # already resolved (sent/failed) keep their real outcome.
      batch_run.batch_run_items.pending.update_all(status: BatchRunItem.statuses[:cancelled]) # rubocop:disable Rails/SkipsModelValidations
      batch_run.update!(status: :completed, completed_at: Time.current)
      # Without this, another admin with the show page open (this
      # request's own redirect is what shows the cancelling admin the
      # new state) would keep seeing "Running" until they refreshed.
      batch_run.broadcast_progress

      redirect_back_or_to resource.show_path(@record), notice: "Cancelled the #{kind_label} batch for #{@record.name}."
    end

    private

      def start_batch_run(kind, description, require_invites_sent: false)
        if !@record.next_show?
          redirect_back_or_to resource.show_path(@record), alert: "Only the next show can have #{description} sent."
        elsif require_invites_sent && !@record.invites_sent?
          redirect_back_or_to resource.show_path(@record), alert: "Send the initial invites before sending #{description}."
        else
          StartBatchRun.call(show: @record, kind: kind)
          redirect_back_or_to resource.show_path(@record), notice: "Started sending #{description} for #{@record.name}."
        end
      rescue StartBatchRun::AlreadyInProgress
        redirect_back_or_to resource.show_path(@record), alert: "Already sending #{description} for #{@record.name} -- hang tight."
      rescue StartBatchRun::EnqueueFailed => e
        redirect_back_or_to resource.show_path(@record), alert: e.message
      end
  end
end

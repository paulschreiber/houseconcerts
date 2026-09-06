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
      # Queried live, not read off batch_run.failed_count: if a previous
      # retry's enqueue of BatchRunRetryFanOutJob itself failed after
      # this run's counters were already reset, failed_count would say 0
      # while these items are still genuinely failed. Gating on the real
      # rows (not the aggregate counter) means that case self-heals --
      # the button and this check still see the failures and allow
      # retrying again -- instead of silently stranding them forever.
      failed_items = batch_run&.batch_run_items&.failed

      if batch_run.nil? || failed_items.none?
        redirect_back_or_to resource.show_path(@record), alert: "There are no failed #{kind_label} sends to retry."
        return
      end

      retry_count = failed_items.count
      kind = batch_run.kind

      # Reopen the run so its progress bar shows again while the retries
      # are in flight -- BatchRunItemJob flips it back to completed once
      # every item (including these) has resolved again. failed_count is
      # reset to 0 (not left at its old value) because every failed item
      # is being retried here, and BatchRunItemJob#record_progress counts
      # each one fresh as it resolves -- without this reset,
      # processed_count would already equal total_count the instant the
      # run reopens, and the very first retried item to finish would
      # falsely flip the run back to "completed" while its siblings were
      # still in flight.
      begin
        batch_run.update!(status: :running, completed_at: nil, failed_count: 0)
        # counted_at mirrors failed_count's reset, per item: it's what
        # BatchRunItemJob#record_progress checks to decide whether an
        # item's resolution still needs counting, so without this reset
        # a retried item's fresh resolution would look already-counted
        # and never update failed_count/sent_count at all. fan_out_enqueued_at
        # is reset alongside it so BatchRunRetryFanOutJob's own claim can
        # enqueue these items again -- it's still set from their first,
        # now-failed attempt.
        failed_items.update_all(counted_at: nil, fan_out_enqueued_at: nil) # rubocop:disable Rails/SkipsModelValidations
      rescue ActiveRecord::RecordNotUnique
        # active_kind_lock only allows one non-completed run per show+kind
        # at a time -- reopening this (older) run collides if a newer run
        # of the same kind is currently pending/running.
        redirect_back_or_to resource.show_path(@record),
                            alert: "Can't retry right now -- a newer #{kind_label} batch is already in progress for #{@record.name}. Try again once it finishes."
        return
      end

      # Handed off to a job (not looped inline here) so a crash partway
      # through enqueuing doesn't strand the remaining failed items --
      # see BatchRunRetryFanOutJob for why that's resumable.
      begin
        BatchRunRetryFanOutJob.perform_later(batch_run.id)
      rescue ActiveRecord::AdapterError, SolidQueue::Job::EnqueueError
        # Solid Queue raises synchronously, at the point perform_later is
        # called, not later in a worker -- so a transient DB problem here
        # would otherwise surface as a raw 500. The run itself is fine
        # (failed_count is already reset and the failed items are still
        # there), so clicking Retry again picks up right where this left
        # off -- the button/gate query the real items, not this counter.
        redirect_back_or_to resource.show_path(@record), alert: "Couldn't start retrying #{kind_label} sends right now -- please try again in a moment."
        return
      end

      redirect_back_or_to resource.show_path(@record), notice: "Retrying #{retry_count} failed #{BatchRun.kind_label(kind).downcase} for #{@record.name}."
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

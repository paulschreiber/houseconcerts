class BatchRunFanOutJob < ApplicationJob
  # How long an item's fan-out claim is trusted before it's treated as
  # abandoned: a crash between claiming an item and enqueuing its job leaves
  # it claimed with nothing to redeliver. Long enough never to fire while a
  # job is still genuinely sending.
  STRANDED_CLAIM_AGE = 10.minutes

  # Retried for transient DB problems only, so a run isn't left "running"
  # with items never enqueued; it's safe to rerun from the start (see
  # perform). A transient DB error during perform_later surfaces as
  # SolidQueue::Job::EnqueueError, not an AdapterError. Real bugs aren't
  # retried.
  retry_on ActiveRecord::AdapterError, SolidQueue::Job::EnqueueError, wait: :polynomially_longer, attempts: 5

  # Creates a run's items (one per recipient) and enqueues a BatchRunItemJob
  # for each, in the background so starting a batch returns at once. Retrying
  # failed items (Madmin::ShowsController#retry_failed_batch_run) runs this
  # too: the run is no longer pending, so it goes straight to enqueuing.
  #
  # Safe to rerun: an item that already exists for a recipient is skipped
  # (unique index), and the run only becomes "running", with its
  # total_count, once every recipient has an item. That phase holds a row
  # lock, so two fan-outs for the same pending run can't interleave; if one
  # dies first, its transaction rolls back and a later attempt redoes it.
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

    # Shows the run's new state at once (a run with no recipients has no item
    # jobs to do it), but only after a transition this call committed.
    batch_run.broadcast_progress if transitioned

    return if batch_run.completed?

    enqueue_unresolved_items(batch_run)
  end

  private

    def claimable(scope)
      scope.where("fan_out_enqueued_at IS NULL OR fan_out_enqueued_at < ?", STRANDED_CLAIM_AGE.ago)
    end

    # Each item is claimed before it's enqueued, so two fan-outs (or a fan-out
    # and a retry) can't both enqueue it; otherwise, if the first send failed,
    # the second could resend it unasked.
    def enqueue_unresolved_items(batch_run)
      claimable(batch_run.batch_run_items.pending).find_each { |item| enqueue_item(item) }

      # Failed items only when an admin's retry reset their claim, so a crash
      # recovery never re-attempts a failure nobody asked to retry.
      batch_run.batch_run_items.failed.where(fan_out_enqueued_at: nil).find_each { |item| enqueue_item(item) }
    end

    # If perform_later raises, the claim is released so a later attempt
    # doesn't skip the item forever.
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

    def recipients_for(batch_run)
      show = batch_run.show
      invitable = Person.invitable_for(show).order(:last_name, :first_name)

      case batch_run.kind
      when "invite"
        invitable
      when "invite_unopened"
        invitable.where(
          "NOT EXISTS (SELECT 1 FROM opens WHERE opens.tag LIKE ? AND opens.email = people.email)",
          "#{ActiveRecord::Base.sanitize_sql_like(show.slug)}:invite%"
        )
      when "remind"
        show.attendees
      else
        raise ArgumentError, "unknown batch run kind: #{batch_run.kind}"
      end
    end
end

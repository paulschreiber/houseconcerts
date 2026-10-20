class BatchRunFanOutJob < ApplicationJob
  # How long an item's fan-out claim is trusted before it's treated as
  # abandoned: a crash between claiming an item and enqueuing its job leaves
  # it claimed with nothing to redeliver. Long enough never to fire while a
  # job is still genuinely sending.
  STRANDED_CLAIM_AGE = 10.minutes

  # How many items are inserted, or claimed and enqueued, at a time.
  SLICE_SIZE = 500

  # Retried for transient DB problems only, so a run isn't left "running"
  # with items never enqueued; it's safe to rerun from the start (see
  # perform). Real bugs aren't retried.
  retry_on ActiveRecord::AdapterError, wait: :polynomially_longer, attempts: 5

  # Creates a run's items (one per recipient) and enqueues a BatchRunItemJob
  # for each, in the background so starting a batch returns at once. Retrying
  # failed items (BatchRun#retry_failed!) runs this
  # too: the run is no longer pending, so it goes straight to enqueuing.
  #
  # Safe to rerun: an item that already exists for a recipient is skipped
  # (the bulk insert ignores rows the unique index rejects), and the run only
  # becomes "running", with its total_count, once every recipient has an
  # item. That phase holds a row lock, so two fan-outs for the same pending
  # run can't interleave; if one dies first, its transaction rolls back and a
  # later attempt redoes it.
  def perform(batch_run_id)
    batch_run = BatchRun.find(batch_run_id)
    return if batch_run.completed?

    transitioned = false

    batch_run.with_lock do
      next unless batch_run.pending?

      create_items(batch_run)

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

    def create_items(batch_run)
      recipients = recipients_for(batch_run)
      recipient_type = recipients.klass.polymorphic_name

      recipients.pluck(:id).each_slice(SLICE_SIZE) do |recipient_ids|
        rows = recipient_ids.map { |id| { recipient_type: recipient_type, recipient_id: id } }
        batch_run.batch_run_items.insert_all(rows) # rubocop:disable Rails/SkipsModelValidations
      end
    end

    # Each item is claimed before it's enqueued, so two fan-outs (or a fan-out
    # and a retry) can't both enqueue it; otherwise, if the first send failed,
    # the second could resend it unasked.
    def enqueue_unresolved_items(batch_run)
      items = batch_run.batch_run_items
      enqueue_claimed(items.pending.where("fan_out_enqueued_at IS NULL OR fan_out_enqueued_at < ?", STRANDED_CLAIM_AGE.ago))

      # Failed items only when an admin's retry reset their claim, so a crash
      # recovery never re-attempts a failure nobody asked to retry.
      enqueue_claimed(items.failed.where(fan_out_enqueued_at: nil))
    end

    # Claims and enqueues the items in scope a slice at a time. SKIP LOCKED
    # leaves a slice another fan-out is claiming to that fan-out; once a claim
    # commits, the item no longer matches scope.
    def enqueue_claimed(scope)
      loop do
        item_ids = BatchRunItem.transaction do
          ids = scope.order(:id).limit(SLICE_SIZE).lock("FOR UPDATE SKIP LOCKED").pluck(:id)
          BatchRunItem.where(id: ids).update_all(fan_out_enqueued_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
          ids
        end
        enqueue_items(item_ids) if item_ids.any?
        break if item_ids.size < SLICE_SIZE
      end
    end

    # If enqueuing raises, the slice's claims are released so a later attempt
    # doesn't skip those items forever.
    def enqueue_items(item_ids)
      ActiveJob.perform_all_later(item_ids.map { |id| BatchRunItemJob.new(id) })
    rescue StandardError
      BatchRunItem.where(id: item_ids).update_all(fan_out_enqueued_at: nil) # rubocop:disable Rails/SkipsModelValidations
      raise
    end

    def recipients_for(batch_run)
      show = batch_run.show
      invitable = Person.invitable_for(show).order(:last_name, :first_name)

      case batch_run.kind
      when "invite"
        invitable
      when "invite_unopened"
        invitable.where.not(Open.invites_to(show).where("opens.email = people.email").arel.exists)
      when "remind"
        show.attendees
      else
        raise ArgumentError, "unknown batch run kind: #{batch_run.kind}"
      end
    end
end

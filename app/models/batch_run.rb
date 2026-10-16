class BatchRun < ApplicationRecord
  belongs_to :show
  # The invite revision an invite batch sends (see StartBatchRun).
  belongs_to :invite_message, optional: true
  has_many :batch_run_items, dependent: :destroy

  enum :kind, { invite: 0, invite_unopened: 1, remind: 2 }
  enum :status, { pending: 0, running: 1, completed: 2 }, default: :pending

  # Each kind's label, its button on the show page, how it's described in
  # messages, whether initial invites must have gone out first, and whether
  # it sends the show's invite (so needs one written).
  KINDS = {
    "invite" => { label: "Invites", button: "Send Invites", description: "invites", requires_invites_sent: false, sends_invite: true },
    "invite_unopened" => { label: "Unopened invites", button: "Send to Unopened", description: "invites to unopened recipients",
                           requires_invites_sent: true, sends_invite: true },
    "remind" => { label: "Reminders", button: "Send Reminders", description: "reminders", requires_invites_sent: true, sends_invite: false }
  }.freeze

  # Raised by retry_failed! and cancel!, with a message for the admin.
  class Refused < StandardError; end

  # Runs that finished and sent at least one message. A run cancelled before
  # sending, or one where every send failed, is also "completed".
  scope :delivered, -> { completed.where(sent_count: 1..) }

  def self.kind_label(kind)
    KINDS.fetch(kind.to_s)[:label]
  end

  def self.kind_description(kind)
    KINDS.fetch(kind.to_s)[:description]
  end

  def self.requires_invites_sent?(kind)
    KINDS.fetch(kind.to_s)[:requires_invites_sent]
  end

  def self.sends_invite?(kind)
    KINDS.fetch(kind.to_s)[:sends_invite]
  end

  def processed_count
    sent_count + failed_count
  end

  # The run's items by outcome, from one query: sent and failed items that
  # have been counted (counted_at), every failed item (including ones
  # awaiting a retry), and cancelled items. Remembered on this object, so
  # the progress partial reuses BatchRunItemJob's count.
  def item_counts
    @item_counts ||= recount_items
  end

  # Counts the items again (see item_counts).
  def recount_items
    # Keyed by [status, 1 if counted_at is set, else 0].
    counts = Hash.new(0).merge(batch_run_items.group(:status).group(Arel.sql("counted_at IS NOT NULL")).count)
    @item_counts = { sent: counts[[ "sent", 1 ]], failed: counts[[ "failed", 1 ]],
                     failed_items: counts[[ "failed", 1 ]] + counts[[ "failed", 0 ]],
                     cancelled: counts[[ "cancelled", 1 ]] + counts[[ "cancelled", 0 ]] }
  end

  # The failures the progress bar shows. A running run's are counted from its
  # items, since the cached failed_count leaves out ones awaiting a retry; a
  # completed run's counts no longer change.
  def displayed_failed_count
    completed? ? failed_count : item_counts[:failed_items]
  end

  # Reopens the run and hands its failed items back to BatchRunFanOutJob.
  # Returns how many are being retried.
  def retry_failed!
    # The items themselves, not a cached counter, so a retry whose enqueue
    # failed partway can be retried again.
    failed_items = batch_run_items.failed
    raise Refused, "There are no failed #{lowercase_label} sends to retry." if failed_items.none?

    # Sends for a show that's happened are useless; its failures stay visible
    # but can't be retried (BatchRunItemJob rechecks this too).
    raise Refused, "#{show.name} has already happened, so its failed #{lowercase_label} sends can’t be retried." if show.occurred?

    retry_count = failed_items.count
    reopen_for_retry!

    # Left "failed", so if the enqueue below fails they can still be offered
    # for retry. counted_at is cleared so they aren't counted until they
    # resolve again, and fan_out_enqueued_at so the fan-out picks them up.
    failed_items.update_all(counted_at: nil, fan_out_enqueued_at: nil) # rubocop:disable Rails/SkipsModelValidations

    enqueue_retry
    retry_count
  end

  # Stops a run that's stuck or unwanted. Nothing else can finish a
  # "running" run with no failures, and until it finishes, active_kind_lock
  # blocks starting another of its kind for the show.
  def cancel!
    raise Refused, "There is no in-progress #{lowercase_label} batch to cancel." if completed?

    # Pending items become "cancelled", which isn't claimable, so a job
    # already enqueued for one sends nothing. Resolved items keep their
    # outcome.
    batch_run_items.pending.update_all(status: BatchRunItem.statuses[:cancelled]) # rubocop:disable Rails/SkipsModelValidations
    update!(status: :completed, completed_at: Time.current)
    # So other admins viewing the show see it too.
    broadcast_progress
  end

  # The kind's label for use mid-sentence, e.g. "reminders".
  def lowercase_label
    self.class.kind_label(kind).downcase
  end

  # Updates the run's progress on any open show page. Called by everything
  # that changes a run's visible state.
  def broadcast_progress
    Turbo::StreamsChannel.broadcast_replace_to(
      [ show, :batch_progress ],
      target: "batch_run_progress_#{kind}",
      partial: "madmin/shows/batch_run_progress",
      locals: { batch_run: self }
    )
  end

  private

    # Reopened only if its status hasn't changed since it was read, so a
    # concurrent cancel isn't overwritten back to "running".
    def reopen_for_retry!
      reopened = BatchRun.where(id: id, status: status)
                         .update_all(status: BatchRun.statuses[:running], completed_at: nil) == 1 # rubocop:disable Rails/SkipsModelValidations
      return if reopened

      raise Refused, "Can’t retry right now -- this #{lowercase_label} batch’s status just changed (it may have been cancelled). Please check and try again."
    rescue ActiveRecord::RecordNotUnique
      # active_kind_lock allows one unfinished run per show and kind.
      raise Refused, "Can’t retry right now -- a newer #{lowercase_label} batch is already in progress for #{show.name}. Try again once it finishes."
    end

    # The fan-out job enqueues the items, so a crash partway through
    # enqueuing doesn't strand the rest.
    def enqueue_retry
      BatchRunFanOutJob.perform_later(id)
    rescue ActiveRecord::AdapterError, SolidQueue::Job::EnqueueError
      # Solid Queue raises during perform_later; retrying again picks up where
      # this left off.
      raise Refused, "Couldn’t start retrying #{lowercase_label} sends right now -- please try again in a moment."
    end
end

class BatchRunItemJob < ApplicationJob
  # Raised when a recipient is no longer eligible to receive this send by
  # the time the job actually runs (e.g. a Person went inactive after the
  # batch was snapshotted). Its own class -- rather than a bare string --
  # so it reads clearly in error_message/logs and stays distinguishable
  # from a genuine unexpected failure.
  class InvalidRecipient < StandardError; end

  # Claimable starting states: "pending" for a first attempt, "failed" so
  # an admin can retry a specific failed send. "sent" is deliberately
  # excluded -- once an item is sent, nothing can ever reclaim it, which
  # is what actually prevents a duplicate email/SMS.
  CLAIMABLE_STATUSES = %w[pending failed].freeze

  def perform(batch_run_item_id)
    # Claim the item (pending/failed -> sent) *before* attempting the
    # send, not after: if this job crashes and Solid Queue redelivers it,
    # the item is already claimed and the redelivered execution just
    # skips straight to record_progress instead of sending a second
    # email/SMS. The tradeoff is the opposite failure mode -- a crash
    # between the claim and the actual send leaves an item marked "sent"
    # that was never delivered -- which we accept as far safer than a
    # duplicate send.
    previous_status = claim(batch_run_item_id)
    item = BatchRunItem.find_by(id: batch_run_item_id)
    return if item.nil?

    # Skipped when this execution didn't win the claim above (the item
    # is already "sent"), so send_to can't run twice. record_progress
    # below still runs regardless -- see its own comment for why that
    # matters: if the execution that *did* win the claim crashed before
    # ever reaching record_progress, this is what catches the run back
    # up instead of leaving it stuck "running" forever with an item that
    # can never be reclaimed to try again.
    if previous_status
      begin
        send_to(item)
      rescue StandardError => e
        # Retried locally (not via ActiveJob's retry_on), not just for
        # emphasis: retry_on would re-invoke this whole method, which
        # would call claim() again -- and since "failed" is one of
        # CLAIMABLE_STATUSES (so an admin can retry a genuinely failed
        # send), that would silently re-trigger send_to and resend a
        # message that may have already gone out. A transient failure
        # writing this outcome shouldn't be able to do that; it should
        # only ever retry the write itself.
        # sent_at is cleared here too, not just status/error_message: claim()
        # sets it unconditionally before send_to runs (it's really "claimed
        # at", not "delivered at"), so a failed item would otherwise keep a
        # real timestamp in a column named sent_at despite never having
        # been delivered -- misleading for anything that trusts
        # "sent_at IS NOT NULL" as "this was actually sent."
        with_transient_retries(item: item, label: "marking it failed") { item.update!(status: :failed, error_message: e.message, sent_at: nil) }
      end
    end

    record_progress(item)
  end

  private

    # A few immediate, local retries for a transient DB error, scoped
    # narrowly to the bookkeeping that follows claim()/send_to() above.
    # This is the fast, in-process path; record_progress's counted_at
    # claim (see its comment) is what actually makes recovery possible
    # beyond these few attempts, via a crash-recovered redelivery of this
    # same job.
    def with_transient_retries(item: nil, label: "recording progress", max_attempts: 3)
      attempts = 0
      begin
        yield
      rescue ActiveRecord::AdapterError => e
        attempts += 1
        if attempts >= max_attempts
          # Logged loudly (this already shows up as a failed job in Solid
          # Queue, but a specific, grep-able line makes the actual gap --
          # and which item/run it's about -- obvious rather than
          # requiring someone to reconstruct it from a bare exception).
          # A worker crash instead of a raised exception leaves no log
          # line at all, but is equally recoverable: Solid Queue's own
          # process-pruning marks a crashed worker's claimed jobs failed,
          # and retrying one (e.g. via Mission Control Jobs) re-invokes
          # record_progress the same as any other redelivery.
          Rails.logger.error(
            "BatchRunItemJob: giving up #{label} for batch_run_item_id=#{item&.id} " \
            "(batch_run_id=#{item&.batch_run_id}) after #{attempts} attempts: " \
            "#{e.class}: #{e.message}"
          )
          raise
        end

        sleep(0.1 * attempts)
        retry
      end
    end

    def claim(batch_run_item_id)
      CLAIMABLE_STATUSES.each do |status|
        claimed = BatchRunItem.where(id: batch_run_item_id, status: status)
                              .update_all(status: "sent", sent_at: Time.current, error_message: nil) # rubocop:disable Rails/SkipsModelValidations
        return status if claimed == 1
      end
      nil
    end

    def send_to(item)
      batch_run = item.batch_run
      recipient = item.recipient
      raise InvalidRecipient, "recipient no longer exists" if recipient.nil?

      case batch_run.kind
      when "invite", "invite_unopened"
        raise InvalidRecipient, "#{recipient.email} is no longer active" unless recipient.active?

        # batch_run.kind ("invite" or "invite_unopened") is passed through
        # as the tracking tag's email_type so opens from the two kinds are
        # distinguishable (rake next_show:opens, etc.) instead of both
        # recording as a plain "invite" open. BatchRunFanOutJob's
        # invite_unopened exclusion query (NOT EXISTS ... tag LIKE
        # "#{slug}:invite%") still matches "invite_unopened" via that
        # prefix, so this doesn't change who gets excluded from a future
        # invite_unopened send.
        InvitesMailer.invite(recipient, batch_run.show, batch_run.kind).deliver_now
      when "remind"
        remind(item, recipient)
      end
    end

    def remind(item, rsvp)
      # Rechecked at send time, not just at fan-out snapshot time: an
      # attendee can be waitlisted/unconfirmed or withdraw their RSVP
      # between when the batch was created and when this specific job
      # actually runs.
      raise InvalidRecipient, "RSVP #{rsvp.id} is no longer a confirmed yes attendee" unless rsvp.confirmed? && rsvp.yes?

      # Email and SMS are two separate external deliveries, not one
      # transaction: each is tracked independently, and each is only
      # marked done *after* it succeeds (not before), so retrying a
      # failed item only re-attempts whichever channel didn't already
      # succeed. The narrow window this leaves -- delivery succeeds but
      # this timestamp write itself fails -- risks a rare duplicate on
      # retry, which we accept in exchange for never silently skipping a
      # channel that actually failed to send.
      unless item.email_sent_at?
        InvitesMailer.remind(rsvp).deliver_now
        item.update!(email_sent_at: Time.current)
      end

      return if rsvp.phone_number.blank?

      return if item.sms_sent_at?

      # A permanently bad number (landline, wrong digits) means this
      # raises every time, marking the whole item "failed" despite the
      # email above having genuinely gone out -- deliberately, not an
      # oversight: item status is one signal for "does this recipient
      # need anything else from us," not two independent per-channel
      # ones, and splitting it would mean tracking a partial-success
      # state through counters/notifications/retry UI that don't
      # distinguish it today. The accepted cost is a retry that keeps
      # re-alerting the admin on the same number -- resolved by fixing
      # the number on the RSVP's own Madmin edit page, which does stop
      # the loop, just not automatically.
      if Rails.env.production?
        client = Twilio::REST::Client.new(Rails.application.credentials.twilio.account_sid, Rails.application.credentials.twilio.auth_token)
        client.api.account.messages.create(
          from: Rails.application.credentials.twilio.sms_sender,
          to: rsvp.phone_number_twilio,
          body: rsvp.sms_reminder
        )
      else
        Rails.logger.debug { "Sending SMS [#{rsvp.phone_number_twilio}]: #{rsvp.sms_reminder}" }
      end
      item.update!(sms_sent_at: Time.current)
    end

    # Claimed via counted_at, not status: status alone can't tell "already
    # sent" apart from "sent, but its outcome was never counted", which is
    # exactly what happens if the execution that claimed the item (see
    # perform above) crashed before ever reaching this method. Gating on
    # counted_at instead means this redelivery -- which still calls this
    # method even though it didn't claim the item -- notices counted_at
    # is nil and does the counting itself, instead of the run staying
    # "running" forever with an item that can never be reclaimed to try
    # again. Reset to NULL by
    # Madmin::ShowsController#retry_failed_batch_run alongside
    # failed_count, so a retried item's next resolution gets freshly
    # counted too, the same as a first attempt.
    #
    # The claim only ever covers the increment below, not the completion
    # check/broadcast that follows it: claiming both together would mean
    # a persistent DB outage that outlasts the increment's own local
    # retries leaves counted_at set with the increment never having
    # happened (an undercount, not just a stuck run), and even a
    # successful increment followed by a failed completion check would
    # leave nothing able to retry just that part -- a redelivery would
    # see counted_at already set and bail out at the top, same as this
    # method's very first no-op case. The increment releases its own
    # claim if it fails, so a redelivery redoes it from scratch (safe,
    # since a failed atomic UPDATE never took effect); the completion
    # check runs unconditionally on every call regardless of whether
    # *this* call did any counting, since it's already idempotent and
    # guarded against re-transitioning or re-notifying.
    def record_progress(item)
      # Only sent/failed items count toward sent_count/failed_count.
      # "cancelled" is the one other status this can see: this job may
      # have already been sitting enqueued for an item when an admin
      # cancelled its run out from under it, and claim() finding
      # "cancelled" not claimable (correctly) still lets this method run
      # -- it just has nothing to count.
      return unless item.sent? || item.failed?

      batch_run = item.batch_run
      claimed = BatchRunItem.where(id: item.id, counted_at: nil).update_all(counted_at: Time.current) == 1 # rubocop:disable Rails/SkipsModelValidations

      if claimed
        counter = item.failed? ? :failed_count : :sent_count
        begin
          # A single atomic SQL statement with no partial-effect
          # possibility -- if it raises, it didn't take effect, so
          # releasing the claim and letting a later attempt redo it from
          # scratch is safe (not #increment!, so concurrent worker
          # threads updating the same batch_run's counters can't lose an
          # update either way).
          with_transient_retries(item: item, label: "incrementing #{counter}") { BatchRun.increment_counter(counter, batch_run.id) } # rubocop:disable Rails/SkipsModelValidations
        rescue StandardError
          BatchRunItem.where(id: item.id).update_all(counted_at: nil) # rubocop:disable Rails/SkipsModelValidations
          raise
        end
      end

      with_transient_retries(item: item, label: "the post-increment completion check/broadcast") do
        batch_run.reload
        if batch_run.processed_count >= batch_run.total_count
          # Guarded by `status: "running"` so only the item that actually
          # finishes the run flips it to completed, even if two items
          # finish at the same time -- and so the failure notification
          # below only ever fires once per completion, not once per item.
          # That guard also makes this whole block idempotent to retry:
          # once it succeeds, a later retry finds status no longer
          # "running" and just no-ops instead of re-transitioning or
          # re-notifying.
          became_completed = BatchRun.where(id: batch_run.id, status: "running")
                                     .update_all(status: BatchRun.statuses[:completed], completed_at: Time.current) == 1 # rubocop:disable Rails/SkipsModelValidations
          batch_run.reload

          NotifyMailer.failed_batch_items(batch_run).deliver_later if became_completed && batch_run.failed_count.positive?
        end

        batch_run.broadcast_progress
      end
    end
end

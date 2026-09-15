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
      # Checked here, immediately before the actual send, not just at
      # cancel_batch_run's own end: claim() above already flipped this
      # item's status away from "pending" before this line even runs, so
      # Madmin::ShowsController#cancel_batch_run -- which only touches
      # items still "pending" -- can't see or stop it. A batch_run can
      # only already be completed *here* (before this item has resolved,
      # so before it could have contributed to a normal completion) if
      # it was cancelled in that exact window. This can't close the
      # window entirely (there's always some gap between a check and an
      # action), but shrinks it from this item's whole time in flight
      # down to one query, right before the real external call.
      if item.batch_run.completed?
        item.update!(status: :cancelled, sent_at: nil)
      else
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
    end

    record_progress(item)
  end

  private

    # A few immediate, local retries for a transient DB error, scoped
    # narrowly to the bookkeeping that follows claim()/send_to() above.
    # This is the fast, in-process path; record_progress's own idempotent
    # recount (see its comment) is what actually makes recovery possible
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
        # counted_at set here too, not just by record_progress: it's what
        # record_progress's live recount filters on to tell "should count
        # right now" apart from "failed, awaiting a retry that hasn't
        # resolved yet" (see record_progress). Setting it as part of this
        # same atomic write -- rather than as record_progress's own,
        # separate claim -- means there's no gap where this item is
        # already "sent"/"failed" but not yet marked countable, so
        # record_progress never needs to claim anything itself; it can
        # just recount unconditionally, any number of times, and always
        # get the right answer.
        claimed = BatchRunItem.where(id: batch_run_item_id, status: status)
                              .update_all(status: "sent", sent_at: Time.current, error_message: nil, counted_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
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

    # Recomputed live from the items themselves (filtered by counted_at
    # -- see claim() above), not accumulated with an additive increment,
    # so this needs no claim of its own and is safe to call any number
    # of times: unconditionally, on every invocation, regardless of
    # whether *this* one is what actually resolved the item.
    #
    # That's deliberate, not incidental: an additive delta can't safely
    # be retried under an uncertain outcome. If the DB connection drops
    # after MySQL commits a `sent_count = sent_count + 1` but before
    # Rails receives the acknowledgment, there's no way to tell "didn't
    # happen" apart from "happened, but I never heard back" -- retrying
    # in the first case is required, and in the second case double-
    # counts. A live recount has no such ambiguity: redone any number of
    # times, for any reason (an ordinary crash-recovered redelivery, or
    # this exact kind of ack-loss uncertainty), it always converges on
    # the same correct answer, since there's no delta to apply twice.
    #
    # Filtered by counted_at, not just status = sent/failed: a failed
    # item awaiting an admin's retry is still "failed" in the database
    # the whole time, but Madmin::ShowsController#retry_failed_batch_run
    # resets its counted_at to NULL specifically so it's excluded here
    # until it actually resolves again -- without that, processed_count
    # would already equal total_count the instant a retried run reopens,
    # before any of the retries have actually run.
    def record_progress(item)
      # Only sent/failed items count toward sent_count/failed_count.
      # "cancelled" is the one other status this can see: this job may
      # have already been sitting enqueued for an item when an admin
      # cancelled its run out from under it, and claim() finding
      # "cancelled" not claimable (correctly) still lets this method run
      # -- it just has nothing to count.
      return unless item.sent? || item.failed?

      batch_run = item.batch_run

      with_transient_retries(item: item) do
        batch_run.with_lock do
          batch_run.update!(
            sent_count: batch_run.batch_run_items.where.not(counted_at: nil).sent.count,
            failed_count: batch_run.batch_run_items.where.not(counted_at: nil).failed.count
          )
        end

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

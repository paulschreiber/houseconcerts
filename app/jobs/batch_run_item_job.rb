class BatchRunItemJob < ApplicationJob
  # The recipient is no longer eligible (e.g. went inactive after the batch
  # started). The item is marked "failed".
  class InvalidRecipient < StandardError; end

  # The send is no longer wanted (the show has happened, or they've RSVPd).
  # The item is marked "cancelled", not "failed": it isn't a delivery
  # problem, so it shouldn't alert the admin or offer a retry.
  class SkippedRecipient < StandardError; end

  # "pending" for a first attempt, "failed" for an admin's retry. A "sent"
  # item can never be reclaimed, which is what prevents a duplicate send.
  CLAIMABLE_STATUSES = %w[pending failed].freeze

  def perform(batch_run_item_id)
    # Claimed (marked "sent") before sending, so a redelivered job doesn't
    # send twice. A crash between the claim and the send leaves an item
    # marked "sent" that wasn't delivered, which is safer than a duplicate.
    claimed = claim(batch_run_item_id) == 1
    item = BatchRunItem.find_by(id: batch_run_item_id)
    return if item.nil?

    # Only the execution that won the claim sends. record_progress runs
    # either way, so a redelivery catches up a run whose sender crashed.
    if claimed
      # A run cancelled after this item was claimed (cancel only touches
      # pending items) is checked once more right before sending.
      if item.batch_run.completed?
        item.update!(status: :cancelled, sent_at: nil)
      else
        begin
          send_to(item)
        rescue SkippedRecipient => e
          with_transient_retries(item: item, label: "marking it skipped") { item.update!(status: :cancelled, error_message: e.message, sent_at: nil) }
        rescue StandardError => e
          # Retried locally, not with retry_on: rerunning perform would
          # reclaim the "failed" item and could resend it. sent_at is
          # cleared, since claim set it. The message is truncated to fit
          # error_message (varchar(255)), or MySQL would reject the write
          # and leave the item "sent" and its run "running".
          error_message = e.message.to_s.truncate(BatchRunItem.columns_hash["error_message"].limit || 255)
          with_transient_retries(item: item, label: "marking it failed") { item.update!(status: :failed, error_message: error_message, sent_at: nil) }
        end
      end
    end

    record_progress(item)
  end

  private

    # A few immediate retries of the bookkeeping after a transient DB error.
    # Beyond these, record_progress's recount lets a redelivered job recover.
    def with_transient_retries(item: nil, label: "recording progress", max_attempts: 3)
      attempts = 0
      begin
        yield
      rescue ActiveRecord::AdapterError => e
        attempts += 1
        if attempts >= max_attempts
          # A specific, grep-able line for the item and run, on top of the
          # failed job in Solid Queue.
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

    # counted_at is set here too, not just by record_progress: it's what
    # record_progress's recount filters on, and setting it in the same atomic
    # write means an item is never "sent"/"failed" without being countable.
    # Returns how many rows it claimed (0 or 1).
    def claim(batch_run_item_id)
      BatchRunItem.where(id: batch_run_item_id, status: CLAIMABLE_STATUSES)
                  .update_all(status: "sent", sent_at: Time.current, error_message: nil, counted_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end

    def send_to(item)
      batch_run = item.batch_run
      recipient = item.recipient
      raise InvalidRecipient, "recipient no longer exists" if recipient.nil?
      # Rechecked at send time: a retry or queued job may run after the show.
      raise SkippedRecipient, "#{batch_run.show.name} has already happened" if batch_run.show.occurred?

      case batch_run.kind
      when "invite", "invite_unopened"
        raise InvalidRecipient, "#{recipient.email} is no longer active" unless recipient.can_invite?
        # They may have RSVPd since the batch started.
        raise SkippedRecipient, "#{recipient.email} has already RSVP'd" if RSVP.exists?(show: batch_run.show, email: recipient.email)

        # The kind becomes the open-tracking tag's email type, so opens of the
        # two kinds stay distinguishable ("invite_unopened" still matches the
        # fan-out's "invite%" exclusion).
        InvitesMailer.invite(recipient, batch_run.show, batch_run.kind).deliver_now
      when "remind"
        remind(item, recipient)
      end
    end

    def remind(item, rsvp)
      # Rechecked at send time: the RSVP may have changed since the batch
      # started.
      raise InvalidRecipient, "RSVP #{rsvp.id} is no longer a confirmed yes attendee" unless rsvp.confirmed? && rsvp.yes?

      # Email and SMS are tracked separately and each marked done only after
      # it succeeds, so a retry only re-sends the channel that failed. (If the
      # delivery succeeds but recording it fails, a retry can duplicate it.)
      unless item.email_sent_at?
        InvitesMailer.remind(rsvp).deliver_now
        item.update!(email_sent_at: Time.current)
      end

      return if rsvp.phone_number.blank?

      return if item.sms_sent_at?

      # A bad number fails the whole item even though the email went out:
      # status is one signal per recipient, not one per channel. Fixing the
      # number on the RSVP stops the retries failing.
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

    # Recounts sent and failed from the items (those with counted_at, set by
    # claim) instead of incrementing, so it's safe to run any number of times,
    # including after a lost database acknowledgment. A retried failed item
    # has its counted_at cleared, so it isn't counted until it resolves again.
    def record_progress(item)
      # Cancelled items still run the completion check: a skipped send can be
      # the last item a run is waiting on.
      return if item.pending?

      batch_run = item.batch_run

      with_transient_retries(item: item) do
        batch_run.with_lock do
          counts = batch_run.batch_run_items.where.not(counted_at: nil).group(:status).count
          batch_run.update!(sent_count: counts.fetch("sent", 0), failed_count: counts.fetch("failed", 0))
        end

        # Cancelled items count as done, or a reopened run with cancelled items
        # could never reach total_count.
        cancelled_count = batch_run.batch_run_items.cancelled.count

        if batch_run.processed_count + cancelled_count >= batch_run.total_count
          # Only the item that finishes a running run completes it, so the
          # failure email goes out once, and a retry of this is a no-op.
          became_completed = BatchRun.where(id: batch_run.id, status: "running")
                                     .update_all(status: BatchRun.statuses[:completed], completed_at: Time.current) == 1 # rubocop:disable Rails/SkipsModelValidations
          batch_run.reload

          NotifyMailer.failed_batch_items(batch_run).deliver_later if became_completed && batch_run.failed_count.positive?
        end

        batch_run.broadcast_progress
      end
    end
end

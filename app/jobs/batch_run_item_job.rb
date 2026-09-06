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
    # no-ops instead of sending a second email/SMS. The tradeoff is the
    # opposite failure mode -- a crash between the claim and the actual
    # send leaves an item marked "sent" that was never delivered -- which
    # we accept as far safer than a duplicate send.
    previous_status = claim(batch_run_item_id)
    return if previous_status.nil?

    item = BatchRunItem.find(batch_run_item_id)

    begin
      send_to(item)
    rescue StandardError => e
      item.update!(status: :failed, error_message: e.message)
    end

    record_progress(item)
  end

  private

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

      case batch_run.kind
      when "invite", "invite_unopened"
        person = item.recipient
        raise InvalidRecipient, "#{person.email} is no longer active" unless person.active?

        InvitesMailer.invite(person, batch_run.show).deliver_now
      when "remind"
        remind(item)
      end
    end

    def remind(item)
      rsvp = item.recipient

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

    def record_progress(item)
      batch_run = item.batch_run

      # A fresh atomic increment every time, even on a retry: retrying a
      # failed item resets the run's failed_count to 0 for exactly the
      # items being retried (see Madmin::ShowsController#retry_failed_batch_run),
      # so every retried item's resolution needs to be counted again here,
      # the same as a first attempt -- not adjusted as a delta against a
      # count that's already sitting at its final value.
      counter = item.failed? ? :failed_count : :sent_count
      # Atomic SQL increment (not #increment!) so concurrent worker
      # threads updating the same batch_run's counters can't lose an
      # update.
      BatchRun.increment_counter(counter, batch_run.id) # rubocop:disable Rails/SkipsModelValidations

      batch_run.reload
      if batch_run.processed_count >= batch_run.total_count
        # Guarded by `status: "running"` so only the item that actually
        # finishes the run flips it to completed, even if two items finish
        # at the same time -- and so the failure notification below only
        # ever fires once per completion, not once per item.
        became_completed = BatchRun.where(id: batch_run.id, status: "running")
                                   .update_all(status: BatchRun.statuses[:completed], completed_at: Time.current) == 1 # rubocop:disable Rails/SkipsModelValidations
        batch_run.reload

        NotifyMailer.failed_batch_items(batch_run).deliver_later if became_completed && batch_run.failed_count.positive?
      end

      # Scoped to this specific batch_run (not just show+kind), so a stale
      # broadcast from an older run of the same kind can't clobber whatever
      # newer run the show page is actually displaying/subscribed to.
      Turbo::StreamsChannel.broadcast_replace_to(
        [ batch_run, :progress ],
        target: "batch_run_progress_#{batch_run.kind}",
        partial: "madmin/shows/batch_run_progress",
        locals: { batch_run: batch_run }
      )
    end
end

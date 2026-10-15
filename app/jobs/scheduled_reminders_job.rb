class ScheduledRemindersJob < ApplicationJob
  # Starts each upcoming show's reminders once its reminder time
  # (Show#reminder_time) has passed, and emails the admin whether they
  # started or not. Runs every 15 minutes (config/recurring.yml), so a show
  # whose time passed while jobs weren't running is picked up on the next run.
  def perform
    Show.reminders_due.each { |show| remind(show) }
  end

  private

    def remind(show)
      return if show.reminders_handled?
      return unless claim_auto_remind?(show)

      # A pending run means an earlier attempt couldn't enqueue its fan-out,
      # and the admin has already been told.
      resuming = show.batch_runs.remind.pending.exists?

      batch_run = StartBatchRun.call(show: show, kind: "remind", automatic: true)
      NotifyMailer.auto_reminders_started(batch_run).deliver_later
    rescue StartBatchRun::AlreadyInProgress
      # Another run is still sending: an admin's (which the next run will see
      # as handled) or one from before a reschedule (which has to finish
      # first). Released so the next run decides.
      release(show)
    rescue StartBatchRun::NotReady => e
      # Not retried: reminders sent once invites go out would reach only the
      # earliest RSVPs. The claim stays, so this email goes out once.
      NotifyMailer.auto_reminders_failed(show, e.message, will_retry: false).deliver_now
    rescue StartBatchRun::EnqueueFailed => e
      # Transient: released so the next run tries again. Sent now, not
      # later, since enqueuing the email would likely fail too.
      release(show)
      NotifyMailer.auto_reminders_failed(show, e.message, will_retry: true).deliver_now unless resuming
    rescue StandardError
      release(show)
      raise
    end

    # Atomic, so two overlapping runs can't both start the same show.
    def claim_auto_remind?(show)
      Show.where(id: show.id, auto_remind_attempted_at: nil)
          .update_all(auto_remind_attempted_at: Time.current) == 1 # rubocop:disable Rails/SkipsModelValidations
    end

    def release(show)
      Show.where(id: show.id).update_all(auto_remind_attempted_at: nil) # rubocop:disable Rails/SkipsModelValidations
    end
end

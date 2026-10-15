# Preview all emails at http://localhost:3000/rails/mailers/notify_mailer
class NotifyMailerPreview < ActionMailer::Preview
  def ses_event_bounce
    NotifyMailer.ses_event(Person.first, "bounce")
  end

  def ses_event_complaint
    NotifyMailer.ses_event(Person.first, "complaint")
  end

  def auto_reminders_started
    NotifyMailer.auto_reminders_started(BatchRun.remind.last || BatchRun.new(show: Show.last, kind: "remind"))
  end

  def auto_reminders_failed
    NotifyMailer.auto_reminders_failed(Show.last, "Send the initial invites before sending reminders.", will_retry: false)
  end
end

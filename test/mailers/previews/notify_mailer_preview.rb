# Preview all emails at http://localhost:3000/rails/mailers/notify_mailer
class NotifyMailerPreview < ActionMailer::Preview
  def ses_event_bounce
    NotifyMailer.ses_event(Person.first, "bounce")
  end

  def ses_event_complaint
    NotifyMailer.ses_event(Person.first, "complaint")
  end
end

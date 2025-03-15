class NotifyMailer < ApplicationMailer
  def rsvp(rsvp, type, old_seats)
    @rsvp = rsvp
    @old_seats = old_seats

    case type
    when "cancel"
      @subject = "Cancellation from #{rsvp.full_name}"
    when "new"
      @subject = "New RSVP from #{rsvp.full_name}"
    when "update"
      @subject = "Updated RSVP from #{rsvp.full_name}"
    end

    mail(to: HC_CONFIG.invites_from,
         subject: @subject,
         delivery_method: delivery_method,
         delivery_method_options: delivery_options)
  end

  def text_message(sender, body)
    @sender = sender
    @body = body

    mail(to: HC_CONFIG.invites_from,
         subject: "SMS from #{@sender}",
         delivery_method: delivery_method,
         delivery_method_options: delivery_options)
  end
end

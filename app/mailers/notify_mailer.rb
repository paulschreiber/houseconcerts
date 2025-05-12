class NotifyMailer < ApplicationMailer
  include NumberHelpers

  def rsvp(rsvp, type, old_seats)
    @rsvp = rsvp
    @old_seats = old_seats

    case type
    when "cancel"
      @subject = "Cancellation from #{rsvp.full_name} [#{rsvp.show.name}]"
    when "new"
      @subject = "New RSVP from #{rsvp.full_name} [#{rsvp.show.name}]"
    when "update"
      @subject = "Updated RSVP from #{rsvp.full_name} [#{rsvp.show.name}]"
    end

    mail(to: Settings.invites_from,
         subject: @subject,
         delivery_method: delivery_method,
         delivery_method_options: delivery_options)
  end

  def text_message(sender, body)
    @body = body

    formatted_phone_number = phone_number_formatted(sender)

    rsvp = RSVP.where(phone_number: formatted_phone_number).last

    if rsvp.nil?
      @sender = sender
    else
      @sender = "#{sender} (#{rsvp.full_name})"
    end

    mail(to: Settings.invites_from,
         subject: "SMS from #{@sender}",
         delivery_method: delivery_method,
         delivery_method_options: delivery_options)
  end
end

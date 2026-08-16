class NotifyMailer < ApplicationMailer
  include NumberHelpers

  default from: -> { formatted_address(Settings.confirms_from_name, Settings.confirms_from_email) }

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

    mail(to: formatted_address(Settings.invites_from_name, Settings.invites_from_email),
         subject: @subject)
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

    mail(to: formatted_address(Settings.invites_from_name, Settings.invites_from_email),
         subject: "SMS from #{@sender}")
  end
end

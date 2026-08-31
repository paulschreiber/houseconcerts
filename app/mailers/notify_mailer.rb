class NotifyMailer < ApplicationMailer
  include NumberHelpers

  default from: -> { formatted_address(Settings.confirms_from_name, Settings.confirms_from_email) }

  def rsvp(rsvp, type, old_seats)
    # Atomic claim keyed on this exact save's updated_at, not a plain
    # boolean: if the enqueued mailer job somehow gets performed more than
    # once for the same underlying save (e.g. a queue redelivery), the
    # second attempt's claim fails and this becomes a no-op -- but a
    # genuinely later save (a real subsequent update/cancel) has a newer
    # updated_at and still claims and sends normally.
    claimed = RSVP.where(id: rsvp.id)
                  .where("admin_notified_at IS NULL OR admin_notified_at < ?", rsvp.updated_at)
                  .update_all(admin_notified_at: rsvp.updated_at) # rubocop:disable Rails/SkipsModelValidations
    return unless claimed.positive?

    @rsvp = rsvp
    @old_seats = old_seats
    # .to_a avoids the view's .any? and .each each triggering a separate query
    @shows_attended = (rsvp.person&.attendance_history || RSVP.none).to_a

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

class InvitesMailer < ApplicationMailer
  FORMAT = "%Y%m%dT%H%M%SZ".freeze

  def make_calendar_url(rsvp)
    base_url = "https://calendar.google.com/calendar/r/eventedit"
    details = "Update reservation: #{rsvp_link(rsvp)}"
    date_range = "#{rsvp.show.start.utc.strftime(FORMAT)}/#{rsvp.show.end.utc.strftime(FORMAT)}"

    params = {
      text: "#{rsvp.show.name} house concert",
      dates: date_range,
      location: rsvp.show.venue.full_address_calendar,
      details: details,
      sf: "true"
    }

    "#{base_url}?#{params.to_query}"
  end

  def invite(person, show, email_type = "invite")
    return unless person && show

    unless person.can_invite?
      logger.warn "Cannot email ineligible person (#{person.email}, #{person.id}, #{person.status})"
      return
    end

    @person = person
    @show = show
    tag = Open.tag_for(show, email_type)
    @rsvp_url = modify_rsvp_url(slug: show.slug, uniqid: person.uniqid)
    @rsvp_url_yes = rsvp_response_url(slug: show.slug, uniqid: person.uniqid, response: :yes)
    @rsvp_url_no = rsvp_response_url(slug: show.slug, uniqid: person.uniqid, response: :no)
    @unsub_url = unsubscribe_url(uniqid: person.uniqid)
    @track_url = open_tracking_url(tag: tag, uniqid: person.uniqid, kind: "person")

    logger.debug "Emailing #{person.email} [#{tag}]"

    headers["List-Unsubscribe"] = "<#{@unsub_url}>"
    # RFC 8058: lets mail clients unsubscribe with one POST to that URL.
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"

    mail(to: person.email_address_with_name, subject: subject_for("You’re invited", show))
  end

  def waitlisted(rsvp)
    return unless sendable_rsvp?(rsvp)

    # Sent at most once, even if the job is redelivered (see claim_delivery?).
    return unless claim_delivery?(RSVP.where(id: rsvp.id), :waitlist_emailed_at)

    rsvp_mail(rsvp, "Waitlisted", email_type: "waitlist")
  end

  def confirm(rsvp)
    return unless sendable_rsvp?(rsvp)

    # Sent at most once, even if the job is redelivered (see claim_delivery?).
    return unless claim_delivery?(RSVP.where(id: rsvp.id), :confirmation_emailed_at)

    @calendar_url = make_calendar_url(rsvp)
    rsvp_mail(rsvp, "RSVP Confirmation", email_type: "confirm")
  end

  def remind(rsvp)
    return unless sendable_rsvp?(rsvp)

    rsvp_mail(rsvp, "Reminder", email_type: "remind")
  end

  # Sent when the RSVP form updates an existing RSVP without the RSVP's token
  # (see RsvpsController#update_existing_rsvp), so the guest finds out about
  # a change they didn't make and has their link to fix it.
  #
  # previous and current are { response:, seats: } as of the change, not
  # read from rsvp when this is sent, in case it has changed again since.
  def rsvp_updated(rsvp, previous, current)
    return unless rsvp

    @previous = previous.symbolize_keys
    @current = current.symbolize_keys
    rsvp_mail(rsvp, "Your RSVP was updated")
  end

  # Sent instead of applying a form submission without the RSVP's token that
  # would cancel or reduce a "yes" RSVP (see
  # RsvpsController#update_existing_rsvp): the guest makes that change with
  # their own link. seats is the RSVP's seat count when that was asked for.
  def rsvp_change_requested(rsvp, seats)
    return unless rsvp

    @seats = seats
    rsvp_mail(rsvp, "Changing your RSVP")
  end

  private

    def subject_for(prefix, show)
      "#{prefix}: #{show.name} house concert (#{show.start_date_short})"
    end

    # A confirmation, waitlist or reminder email is sent later than it's
    # queued; an RSVP changed to "no" in between gets nothing.
    def sendable_rsvp?(rsvp)
      return false unless rsvp
      return true if rsvp.yes?

      logger.warn "RSVP #{rsvp.id} is no longer a yes"
      false
    end

    def rsvp_link(rsvp)
      modify_rsvp_url(slug: rsvp.show.slug, uniqid: rsvp.uniqid)
    end

    # Mails the guest about their RSVP, with their link to change it and, for
    # an email_type, the open-tracking pixel.
    def rsvp_mail(rsvp, subject_prefix, email_type: nil)
      @rsvp = rsvp
      @rsvp_url = rsvp_link(rsvp)
      @track_url = open_tracking_url(tag: Open.tag_for(rsvp.show, email_type), uniqid: rsvp.uniqid, kind: "rsvp") if email_type

      mail(to: rsvp.email_address_with_name, subject: subject_for(subject_prefix, rsvp.show))
    end
end

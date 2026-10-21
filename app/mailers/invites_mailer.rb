class InvitesMailer < ApplicationMailer
  helper JsonLdHelper

  before_action :set_rsvp, except: :invite

  def invite
    @person = params[:person]
    @show = params[:show]
    email_type = params.fetch(:email_type, "invite")
    return unless @person && @show

    unless @person.can_invite?
      logger.warn "Cannot email ineligible person (#{@person.email}, #{@person.id}, #{@person.status})"
      return
    end

    tag = Open.tag_for(@show, email_type)
    @rsvp_url = modify_rsvp_url(slug: @show.slug, uniqid: @person.uniqid)
    @rsvp_url_yes = rsvp_response_url(slug: @show.slug, uniqid: @person.uniqid, response: :yes)
    @rsvp_url_no = rsvp_response_url(slug: @show.slug, uniqid: @person.uniqid, response: :no)
    @unsub_url = unsubscribe_url(uniqid: @person.uniqid)
    @track_url = open_tracking_url(tag: tag, uniqid: @person.uniqid, kind: "person")

    logger.debug "Emailing #{@person.email} [#{tag}]"

    headers["List-Unsubscribe"] = "<#{@unsub_url}>"
    # RFC 8058: lets mail clients unsubscribe with one POST to that URL.
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"

    mail(to: @person.email_address_with_name, subject: subject_for("You’re invited", @show))
  end

  def waitlisted
    return unless sendable_rsvp?

    # Sent at most once, even if the job is redelivered (see claim_delivery?).
    return unless claim_delivery?(RSVP.where(id: @rsvp.id), :waitlist_emailed_at)

    rsvp_mail("Waitlisted", email_type: "waitlist")
  end

  def confirm
    return unless sendable_rsvp?

    # Sent at most once, even if the job is redelivered (see claim_delivery?).
    return unless claim_delivery?(RSVP.where(id: @rsvp.id), :confirmation_emailed_at)

    show = @rsvp.show
    raise ArgumentError, "#{show.name} isn’t complete: it needs to be confirmed, with an artist" unless show.complete?

    # The show for the guest's calendar, with the full address and their link
    # to change their RSVP. Gmail offers it as an "Add to Calendar" card.
    event = show.ical_event(url: @rsvp_url, location: show.venue.full_address_calendar)
    event.description = "Update reservation: #{@rsvp_url}"
    # Plain text/calendar: method=PUBLISH on the Content-Type can make Outlook
    # show the whole email as a calendar item.
    attachments[show.ics_filename] = { mime_type: "text/calendar", content: Show.ical([ event ]) }
    rsvp_mail("RSVP Confirmation", email_type: "confirm")
  end

  def remind
    return unless sendable_rsvp?

    rsvp_mail("Reminder", email_type: "remind")
  end

  # Sent when the RSVP form updates an existing RSVP without the RSVP's token
  # (see RsvpsController#update_existing_rsvp), so the guest finds out about
  # a change they didn't make and has their link to fix it.
  #
  # The previous and current params are { response:, seats: } as of the
  # change, not read from the RSVP when this is sent, in case it has changed
  # again since.
  def rsvp_updated
    @previous = params[:previous]
    @current = params[:current]
    rsvp_mail("Your RSVP was updated")
  end

  # Sent instead of applying a form submission without the RSVP's token that
  # would cancel or reduce a "yes" RSVP (see
  # RsvpsController#update_existing_rsvp): the guest makes that change with
  # their own link. The seats param is the RSVP's seat count when that was
  # asked for.
  def rsvp_change_requested
    @seats = params[:seats]
    rsvp_mail("Changing your RSVP")
  end

  private

    # Every email but the invite is about an RSVP, passed as the rsvp param.
    def set_rsvp
      @rsvp = params[:rsvp]
      @rsvp_url = modify_rsvp_url(slug: @rsvp.show.slug, uniqid: @rsvp.uniqid)
    end

    def subject_for(prefix, show)
      "#{prefix}: #{show.event_name} (#{show.start_date_short})"
    end

    # A confirmation, waitlist or reminder email is sent later than it's
    # queued; an RSVP changed to "no" in between gets nothing.
    def sendable_rsvp?
      return true if @rsvp.yes?

      logger.warn "RSVP #{@rsvp.id} is no longer a yes"
      false
    end

    # Mails the guest about their RSVP, with their link to change it (see
    # set_rsvp) and, for an email_type, the open-tracking pixel.
    def rsvp_mail(subject_prefix, email_type: nil)
      @track_url = open_tracking_url(tag: Open.tag_for(@rsvp.show, email_type), uniqid: @rsvp.uniqid, kind: "rsvp") if email_type

      mail(to: @rsvp.email_address_with_name, subject: subject_for(subject_prefix, @rsvp.show))
    end
end

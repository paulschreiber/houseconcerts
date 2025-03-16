class InvitesMailer < ApplicationMailer
  FORMAT = "%Y%m%dT%H%M%SZ".freeze

  def make_calendar_url(rsvp)
    base_url = "https://calendar.google.com/calendar/r/eventedit"
    rsvp_url = url_for(controller: :rsvps, action: :new, slug: rsvp.show.slug, uniqid: rsvp.uniqid)
    details = "Update reservation: #{rsvp_url}"
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

    unless person.is_a?(Person)
      logger.warn "First parameter is of type #{person.class} and must be of type Person"
      return
    end

    unless show.is_a?(Show)
      logger.warn "Second parameter is of type #{show.class} and must be of type Show"
      return
    end

    unless person.active?
      logger.warn "Cannnot email inactive person (#{person.email}, #{person.id}, #{person.status})"
      return
    end

    @person = person

    @show = show
    tag = "#{show.slug}:#{email_type}"
    @rsvp_url = url_for(controller: :rsvps, action: :new, slug: show.slug, uniqid: person.uniqid)
    @rsvp_url_yes = url_for(controller: :rsvps, action: :new, slug: show.slug, uniqid: person.uniqid, response: :yes)
    @rsvp_url_no = url_for(controller: :rsvps, action: :new, slug: show.slug, uniqid: person.uniqid, response: :no)
    @unsub_url = url_for(controller: :mailing_list, action: :unsubscribe, uniqid: person.uniqid)
    @track_url = url_for(controller: :opens, action: :index, uniqid: person.uniqid, tag: tag)

    subject = "You’re invited: #{show.name} house concert (#{show.start_date_short})"

    logger.debug "Emailing #{person.email} [#{tag}]"

    headers["List-Unsubscribe"] = @unsub_url

    mail(to: person.email_address_with_name,
         subject: subject,
         delivery_method: delivery_method,
         delivery_method_options: delivery_options)
  end

  def waitlisted(rsvp, email_type = "waitlist")
    return unless rsvp

    unless rsvp.is_a?(RSVP)
      logger.warn "First parameter is of type #{rsvp.class} and must be of type RSVP"
      return
    end

    unless rsvp.seats_reserved.to_i.positive?
      logger.warn "RSVP #{rsvp.id} has 0 seats"
      return
    end

    @rsvp = rsvp
    tag = "#{rsvp.show.slug}:#{email_type}"
    @track_url = url_for(controller: :opens, action: :index, uniqid: rsvp.uniqid, tag: tag)
    @rsvp_url = url_for(controller: :rsvps, action: :new, slug: rsvp.show.slug, uniqid: rsvp.uniqid)

    subject = "Waitlisted: #{rsvp.show.name} house concert (#{rsvp.show.start_date_short})"

    mail(to: rsvp.email_address_with_name,
         subject: subject,
         delivery_method: delivery_method,
         delivery_method_options: delivery_options)
  end

  def confirm(rsvp, email_type = "confirm")
    return unless rsvp

    unless rsvp.is_a?(RSVP)
      logger.warn "First parameter is of type #{rsvp.class} and must be of type RSVP"
      return
    end

    unless rsvp.seats_reserved.to_i.positive?
      logger.warn "RSVP #{rsvp.id} has 0 seats"
      return
    end

    @rsvp = rsvp
    tag = "#{rsvp.show.slug}:#{email_type}"
    @track_url = url_for(controller: :opens, action: :index, uniqid: rsvp.uniqid, tag: tag)
    @rsvp_url = url_for(controller: :rsvps, action: :new, slug: rsvp.show.slug, uniqid: rsvp.uniqid)
    @calendar_url = make_calendar_url(rsvp)

    subject = "RSVP Confirmation: #{rsvp.show.name} house concert (#{rsvp.show.start_date_short})"

    mail(to: rsvp.email_address_with_name,
         subject: subject,
         delivery_method: delivery_method,
         delivery_method_options: delivery_options)
  end

  def remind(rsvp, email_type = "remind")
    return unless rsvp

    unless rsvp.is_a?(RSVP)
      logger.warn "First parameter is of type #{rsvp.class} and must be of type RSVP"
      return
    end

    unless rsvp.seats_reserved.to_i.positive?
      logger.warn "RSVP #{rsvp.id} has 0 seats"
      return
    end

    @rsvp = rsvp
    tag = "#{rsvp.show.slug}:#{email_type}"
    @rsvp_url = url_for(controller: :rsvps, action: :new, slug: rsvp.show.slug, uniqid: rsvp.uniqid)
    @rsvp_url_yes = url_for(controller: :rsvps, action: :new, slug: rsvp.show.slug, uniqid: rsvp.uniqid, response: :yes)
    @rsvp_url_no = url_for(controller: :rsvps, action: :new, slug: rsvp.show.slug, uniqid: rsvp.uniqid, response: :no)
    @track_url = url_for(controller: :opens, action: :index, uniqid: rsvp.uniqid, tag: tag)

    subject = "Reminder: #{rsvp.show.name} house concert (#{rsvp.show.start_date_short})"

    mail(to: rsvp.email_address_with_name,
         subject: subject,
         delivery_method: delivery_method,
         delivery_method_options: delivery_options)
  end
end

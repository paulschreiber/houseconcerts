class Invites < ApplicationMailer
  USE_MANDRILL = false

  def invite(person, show, email_type = 'invite')
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
    @unsub_url = url_for(controller: :mailing_list, action: :unsubscribe, uniqid: person.uniqid)
    @track_url = url_for(controller: :opens, action: :index, uniqid: person.uniqid, tag: tag)

    subject = "You’re invited: #{show.name} house concert (#{show.start_date_short})"

    logger.debug "Emailing #{person.email} [#{tag}]"

    if Rails.env.production? && USE_MANDRILL
      @unsub_url = "*|UNSUB:#{@unsub_url}|*"
      headers['X-MC-Tags'] = tag

      delivery_options = {
        user_name: HC_CONFIG.mandrill_username,
        password: HC_CONFIG.mandrill_api_key,
        port: 587,
        address: 'smtp.mandrillapp.com'
      }

      mail(to: person.email_address_with_name,
           subject: subject,
           delivery_method: :smtp,
           delivery_method_options: delivery_options)
    elsif Rails.env.production?
      mail(to: person.email_address_with_name,
           subject: subject,
           delivery_method: :sendmail)
    else
      mail(to: person.email_address_with_name, subject: subject)
    end
  end

  def confirm(rsvp, email_type = 'confirm')
    return unless rsvp

    unless rsvp.is_a?(RSVP)
      logger.warn "First parameter is of type #{rsvp.class} and must be of type RSVP"
      return
    end

    unless rsvp.seats.to_i > 0
      logger.warn "RSVP #{rsvp.id} has 0 seats"
      return
    end

    @rsvp = rsvp
    tag = "#{rsvp.show.slug}:#{email_type}"
    @track_url = url_for(controller: :opens, action: :index, uniqid: rsvp.uniqid, tag: tag)

    subject = "RSVP Confirmation: #{rsvp.show.name} house concert (#{rsvp.show.start_date_short})"

    if Rails.env.production?
      mail(to: rsvp.email_address_with_name,
           subject: subject,
           delivery_method: :sendmail)
    else
      mail(to: rsvp.email_address_with_name, subject: subject)
    end
  end
end

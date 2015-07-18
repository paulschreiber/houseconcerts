class Invites < ApplicationMailer
  def invite(person, show)
		return unless person && show && person.is_a?(Person) && show.is_a?(Show)

    unless person.active?
      logger.warn "Cannnot email inactive person (#{person.email}, #{person.id}, #{person.status})"
      return
    end

    @person = person

    @show = show
    @rsvp_url = url_for(controller: :rsvps, action: :new, slug: show.slug, uniqid: person.uniqid)
    @unsub_url = url_for(controller: :mailing_list, action: :unsubscribe, uniqid: person.uniqid)

    subject = "You’re invited: #{show.name} house concert (#{show.start_date_short})"

    if Rails.env.production?
      @unsub_url = "*|UNSUB:#{@unsub_url}|*"
      headers["X-MC-Tags"] = "invite #{show.slug}"

      delivery_options = {
        user_name: HC_CONFIG.mandrill_username,
        password: HC_CONFIG.mandrill_api_key,
        port: 587,
        address: "smtp.mandrillapp.com"
      }

      mail(to: person.email_address_with_name,
          subject: subject,
          delivery_method: :smtp,
          delivery_method_options: delivery_options)
    else
      mail(to: person.email_address_with_name, subject: subject)
    end

  end
end

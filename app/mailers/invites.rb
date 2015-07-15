class Invites < ApplicationMailer
  def invite(person, show)
    @person = person
    @show = show
    @rsvp_url = url_for(controller: :rsvps, action: :new, slug: show.slug, uniqid: person.uniqid)
    subject = "You’re invited: #{show.name} house concert (#{show.start_date_short})"

    delivery_options = {
      user_name: HC_CONFIG.mandrill_username,
      password: HC_CONFIG.mandrill_api_key,
      port: 587,
      address: "smtp.mandrillapp.com"
    }

    headers["X-MC-Tags"] = "invite:#{show.slug}"

    mail(to: person.email_address_with_name,
        subject: subject,
        delivery_method: :smtp,
        delivery_method_options: delivery_options)

  end
end

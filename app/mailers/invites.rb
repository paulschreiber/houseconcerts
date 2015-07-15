class Invites < ApplicationMailer
  def invite(person, show)
    @person = person
    @show = show
    @rsvp_url = url_for(controller: :rsvps, action: :new, slug: show.slug, uniqid: person.uniqid)

    mail(to: person.email_address_with_name)

  end
end

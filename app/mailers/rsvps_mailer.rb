class RsvpsMailer < ApplicationMailer
  def notify(rsvp)
    @rsvp = rsvp

    mail(to: HC_CONFIG.invites_from,
         subject: "RSVP from #{rsvp.full_name}",
         delivery_method: delivery_method,
         delivery_method_options: delivery_options)
  end
end

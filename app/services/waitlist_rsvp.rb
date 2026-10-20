class WaitlistRSVP
  def self.call(rsvp)
    return false unless rsvp.waitlist!

    InvitesMailer.with(rsvp: rsvp).waitlisted.deliver_later
    true
  end
end

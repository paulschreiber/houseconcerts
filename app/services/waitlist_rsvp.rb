class WaitlistRSVP
  def self.call(rsvp)
    return false unless rsvp.waitlist!

    InvitesMailer.waitlisted(rsvp).deliver_later
    true
  end
end

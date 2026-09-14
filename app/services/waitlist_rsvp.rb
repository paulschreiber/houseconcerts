class WaitlistRSVP
  def self.call(rsvp)
    RSVPStatusTransition.call(rsvp, transition: :waitlist!, mailer_method: :waitlisted)
  end
end

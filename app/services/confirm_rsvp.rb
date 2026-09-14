class ConfirmRSVP
  def self.call(rsvp)
    RSVPStatusTransition.call(rsvp, transition: :confirm!, mailer_method: :confirm)
  end
end

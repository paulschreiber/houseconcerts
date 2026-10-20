class ConfirmRSVP
  def self.call(rsvp)
    return false unless rsvp.confirm!

    InvitesMailer.confirm(rsvp).deliver_later
    true
  end
end

class ConfirmRSVP
  def self.call(rsvp)
    return false unless rsvp.confirm!

    InvitesMailer.with(rsvp: rsvp).confirm.deliver_later
    true
  end
end

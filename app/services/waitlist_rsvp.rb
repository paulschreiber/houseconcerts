class WaitlistRSVP
  def self.call(rsvp)
    new(rsvp).call
  end

  def initialize(rsvp)
    @rsvp = rsvp
  end

  def call
    return false unless rsvp.waitlist!

    InvitesMailer.waitlisted(rsvp).deliver_later
    true
  end

  private

    attr_reader :rsvp
end

class WaitlistRSVP
  def self.call(rsvp)
    new(rsvp).call
  end

  def initialize(rsvp)
    @rsvp = rsvp
  end

  def call
    InvitesMailer.waitlisted(rsvp).deliver_now if rsvp.waitlist!
  end

  private

    attr_reader :rsvp
end

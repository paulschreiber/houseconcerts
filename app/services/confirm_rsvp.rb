class ConfirmRSVP
  def self.call(rsvp)
    new(rsvp).call
  end

  def initialize(rsvp)
    @rsvp = rsvp
  end

  def call
    InvitesMailer.confirm(rsvp).deliver_now if rsvp.confirm!
  end

  private

    attr_reader :rsvp
end

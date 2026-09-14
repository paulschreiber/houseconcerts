class ConfirmRSVP
  def self.call(rsvp)
    new(rsvp).call
  end

  def initialize(rsvp)
    @rsvp = rsvp
  end

  def call
    return false unless rsvp.confirm!

    InvitesMailer.confirm(rsvp).deliver_later
    true
  end

  private

    attr_reader :rsvp
end

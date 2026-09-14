class RSVPStatusTransition
  def self.call(rsvp, transition:, mailer_method:)
    new(rsvp, transition: transition, mailer_method: mailer_method).call
  end

  def initialize(rsvp, transition:, mailer_method:)
    @rsvp = rsvp
    @transition = transition
    @mailer_method = mailer_method
  end

  def call
    return false unless rsvp.public_send(transition)

    InvitesMailer.public_send(mailer_method, rsvp).deliver_later
    true
  end

  private

    attr_reader :rsvp, :transition, :mailer_method
end

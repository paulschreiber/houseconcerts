class InvitePerson
  def self.call(person, show, deliver_now: false)
    new(person, show, deliver_now:).call
  end

  def initialize(person, show, deliver_now: false)
    @person = person
    @show = show
    @deliver_now = deliver_now
  end

  def call
    message = InvitesMailer.invite(person, show)
    deliver_now ? message.deliver_now : message.deliver_later
    true
  rescue StandardError => e
    Rails.logger.error("InvitePerson failed to #{deliver_now ? 'send' : 'enqueue'} an invite for #{person.email}: #{e.message}")
    false
  end

  private

    attr_reader :person, :show, :deliver_now
end

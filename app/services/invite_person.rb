class InvitePerson
  # Raised when the show has no invite written yet.
  class NotReady < StandardError; end

  def self.call(person, show, deliver_now: false)
    new(person, show, deliver_now:).call
  end

  def initialize(person, show, deliver_now: false)
    @person = person
    @show = show
    @deliver_now = deliver_now
  end

  # True if the invite was sent or queued. Raises NotReady if the show has no
  # invite written.
  def call
    raise NotReady, "Write the invite for #{show.name} first." unless show.invite_message

    send_invite
  end

  private

    def send_invite
      message = InvitesMailer.with(person: person, show: show).invite
      deliver_now ? message.deliver_now : message.deliver_later
      true
    rescue StandardError => e
      Rails.logger.error("InvitePerson failed to #{deliver_now ? 'send' : 'enqueue'} an invite for #{person.email}: #{e.message}")
      false
    end

    attr_reader :person, :show, :deliver_now
end

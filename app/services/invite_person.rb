class InvitePerson
  def self.call(person, show)
    new(person, show).call
  end

  def initialize(person, show)
    @person = person
    @show = show
  end

  def call
    InvitesMailer.invite(person, show).deliver_later
    true
  rescue StandardError => e
    Rails.logger.error("InvitePerson failed to enqueue an invite for #{person.email}: #{e.message}")
    false
  end

  private

    attr_reader :person, :show
end

class InvitePerson
  def self.call(person, show)
    new(person, show).call
  end

  def initialize(person, show)
    @person = person
    @show = show
  end

  def call
    InvitesMailer.invite(person, show).deliver_now
  end

  private

    attr_reader :person, :show
end

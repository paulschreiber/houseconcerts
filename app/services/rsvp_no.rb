class RSVPNo
  def self.call(person, show)
    new(person, show).call
  end

  def initialize(person, show)
    @person = person
    @show = show
  end

  def call
    rsvp = RSVP.find_or_initialize_by(email: person.email, show: show)
    rsvp.first_name = person.first_name
    rsvp.last_name = person.last_name
    rsvp.phone_number = person.phone_number
    rsvp.postcode = person.postcode
    rsvp.response = "no"
    rsvp.save
  end

  private

    attr_reader :person, :show
end

class RSVPNo
  def self.call(person, show)
    new(person, show).call
  end

  def initialize(person, show)
    @person = person
    @show = show
  end

  # Two concurrent clicks for the same person/show can both miss the
  # find_or_initialize_by above and race to create; the DB's unique index
  # rejects the loser, which we recover by updating the row the winner created.
  def call
    attrs = person.rsvp_prefill_attributes.merge(response: "no")
    rsvp = RSVP.find_or_initialize_by(email: person.email, show: show)
    rsvp.assign_attributes(attrs)
    rsvp.save
  rescue ActiveRecord::RecordNotUnique
    RSVP.find_by(email: person.email, show: show).update(attrs)
  end

  private

    attr_reader :person, :show
end

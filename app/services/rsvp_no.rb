class RSVPNo
  def self.call(person, show)
    new(person, show).call
  end

  def initialize(person, show)
    @person = person
    @show = show
  end

  # Two concurrent clicks for the same person and show can both miss
  # find_or_initialize_by and race to create; the unique index rejects the
  # second, which then updates the row the first created. If there's no such
  # row (a different unique index, e.g. a uniqid collision), it returns false.
  def call
    attrs = person.rsvp_prefill_attributes.merge(response: "no")
    rsvp = RSVP.find_or_initialize_by(email: person.email, show: show)
    rsvp.assign_attributes(attrs)
    rsvp.save
  rescue ActiveRecord::RecordNotUnique
    RSVP.find_by(email: person.email, show: show)&.update(attrs) || false
  end

  private

    attr_reader :person, :show
end

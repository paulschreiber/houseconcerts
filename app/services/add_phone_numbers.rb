# Fills in missing phone numbers on the mailing list from RSVPs, using each
# person's most recent RSVP that has one: from a single show's RSVPs, or all
# of them.
class AddPhoneNumbers
  def self.call(show = nil)
    new(show).call
  end

  def initialize(show = nil)
    @show = show
  end

  # Returns the people whose phone numbers were added.
  def call
    rsvps = RSVP.where.not(phone_number: [ nil, "" ])
    rsvps = rsvps.where(show:) if show
    # Later RSVPs overwrite earlier ones, so each email maps to its latest.
    latest_phone_by_email = rsvps.order(:id).pluck(:email, :phone_number).to_h

    Person.where(phone_number: [ nil, "" ], email: latest_phone_by_email.keys).order(:last_name, :first_name).select do |person|
      person.update(phone_number: latest_phone_by_email[person.email])
    end
  end

  private

    attr_reader :show
end

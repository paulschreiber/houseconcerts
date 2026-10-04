# Adds the people who RSVPd yes to a show but aren't on the mailing list.
# Someone who already has a Person record -- because they unsubscribed, or
# are bouncing or moved -- is skipped, never re-added.
class AddNonsubscribers
  # added and skipped are RSVPs; failed maps each RSVP whose person couldn't
  # be saved to the validation errors.
  Result = Data.define(:added, :skipped, :failed)

  def self.call(show)
    new(show).call
  end

  def initialize(show)
    @show = show
  end

  def call
    result = Result.new(added: [], skipped: [], failed: {})

    RSVP.nonsubscribers(show).order(:last_name, :first_name).each do |rsvp|
      if rsvp.person_exists?
        result.skipped << rsvp
        next
      end

      person = rsvp.create_person
      if person.persisted?
        result.added << rsvp
      else
        result.failed[rsvp] = person.errors.full_messages.to_sentence
      end
    rescue ActiveRecord::RecordNotUnique
      # Added by another run (a second click, or the rake task) since the
      # check above, so they're on the list either way.
      next
    end

    result
  end

  private

    attr_reader :show
end

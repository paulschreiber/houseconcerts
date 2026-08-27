# notify_rsvp can be "yes", "all" (yes and no) or blank/false/empty string
class NotifyAdminOfRSVP
  def self.call(rsvp)
    new(rsvp).call
  end

  def initialize(rsvp)
    @rsvp = rsvp
  end

  def call
    return unless notify?

    NotifyMailer.rsvp(rsvp, type, old_seats).deliver_later
  end

  private

    attr_reader :rsvp

    def notify?
      # don't notify of any RSVPs when notify is empty
      return false if Settings.notify_rsvp.blank?

      # don't notify if show was in the past
      return false if rsvp.show.occurred?

      # don't notify if nothing important changed (seats, response, name) about the RSVP
      return false unless rsvp.saved_changes.keys.intersect?(RSVP::RSVP_NOTIFY_ATTRIBUTES) && rsvp.persisted?

      # don't notify of new "no" RSVPs when notify is "yes" only
      return false if Settings.notify_rsvp == "yes" && rsvp.response != "yes" && rsvp.previously_new_record?

      # notify if there's a cancellation (no -> yes)
      # notify if there's a new yes
      # notify if there's a updated yes
      # notify if there's a new no (when notify is "all")
      true
    end

    def type
      if rsvp.saved_changes.include?("response") && rsvp.saved_changes["response"][1] == "no"
        "cancel"
      elsif rsvp.previously_new_record?
        "new"
      else
        "update"
      end
    end

    def old_seats
      rsvp.saved_changes.include?("seats_reserved") ? rsvp.saved_changes["seats_reserved"][0] : nil
    end
end

# Applies an Amazon SES event (as delivered by EventBridge, see
# SesEventsController) to the mailing list:
# - a permanent bounce marks the person bouncing, so they're no longer invited
# - a complaint (marked as spam) removes them, like an unsubscribe
# and emails the admin about it. Anything else (transient bounces, deliveries,
# opens, ...) is ignored. Receiving the same event twice changes nothing (and
# sends nothing) the second time.
class SesEvent
  def self.call(event)
    new(event).call
  end

  def initialize(event)
    @detail = event["detail"] if event.is_a?(Hash)
  end

  def call
    return unless @detail.is_a?(Hash)

    case @detail["eventType"]
    when "Bounce"
      update(recipients("bounce", "bouncedRecipients"), :bouncing) if @detail.dig("bounce", "bounceType") == "Permanent"
    when "Complaint"
      update(recipients("complaint", "complainedRecipients"), :removed)
    end
  end

  private

    def event_type = @detail["eventType"].downcase

    def recipients(section, list)
      entries = @detail.dig(section, list)
      return [] unless entries.is_a?(Array)

      entries.filter_map { |entry| entry["emailAddress"].to_s.strip.downcase.presence if entry.is_a?(Hash) }
    end

    # Someone already removed stays removed: a bounce shouldn't undo an
    # unsubscribe or an earlier complaint. The status is checked again under a
    # lock, so two copies of an event arriving at once don't both email the
    # admin.
    def update(emails, status)
      Person.where(email: emails).where.not(status: [ :removed, status ]).find_each do |person|
        changed = person.with_lock do
          next false if person.removed? || person.status == status.to_s

          person.update!(status:)
        end
        next unless changed

        Rails.logger.info("SES #{event_type}: person #{person.id} is now #{status}")
        NotifyMailer.ses_event(person, event_type).deliver_later
      end
    end
end

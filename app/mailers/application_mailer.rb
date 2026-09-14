class ApplicationMailer < ActionMailer::Base
  default from: -> { formatted_address(Settings.invites_from_name, Settings.invites_from_email) }
  layout "mailer"

  before_action { Thread.current[:mailer_claim] = nil }

  # Mailer actions that must send at most once (confirm/waitlisted/rsvp)
  # call #claim_delivery? to atomically mark a record before building the
  # message, so a redelivered job can't send the same email twice. If the
  # actual send then fails, ActiveJob's own retry of the same job would
  # find the claim already taken and silently skip resending -- release
  # the claim on any exception during that job (processing or delivery)
  # so a retry can actually resend, then let it fail/retry as normal.
  def self.handle_exception(exception)
    if (claim = Thread.current[:mailer_claim])
      claim[:scope].update_all(claim[:column] => nil) # rubocop:disable Rails/SkipsModelValidations
    end
    super
  end

  private

    # Atomically claims a one-time delivery: sets `column` to now on every
    # record in `scope` (typically a single-record where(id: ...)) that
    # doesn't already have it set, returning true only if it actually
    # changed a row. Remembers the claim so .handle_exception can release
    # it if this job goes on to fail.
    def claim_delivery?(scope, column)
      claimed = scope.where(column => nil).update_all(column => Time.current) # rubocop:disable Rails/SkipsModelValidations
      Thread.current[:mailer_claim] = { scope: scope, column: column } if claimed.positive?
      claimed.positive?
    end

    def formatted_address(name, username)
      Mail::Address.new("#{username}@#{Settings.domain}").tap { |address| address.display_name = name }.format
    end
end

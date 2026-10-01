# Throttle repeated guesses against the uniqid-keyed public URLs (RSVP
# modify links, RSVP/mailing-list thank-you pages, unsubscribe, and the
# email open-tracking pixel) — uniqid is a random token, not a secret meant
# to withstand unlimited brute-force attempts.
module Rack
  class Attack
    throttle("uniqid-lookups/ip", limit: 20, period: 1.minute) do |req|
      req.ip if req.path.match?(%r{\A/(rsvps/(show|thanks)|list/thanks|unsubscribe|open)/})
    end

    # Admin sign-in and password reset: limit password guessing, and stop the
    # reset form being used to flood an admin's inbox. Each is limited per IP
    # and per email address, so neither rotating IPs nor rotating emails gets
    # around it.
    ADMIN_SIGN_IN_PATH = "/#{Settings.admin_prefix}/sign_in".freeze
    ADMIN_PASSWORD_PATH = "/#{Settings.admin_prefix}/password".freeze

    def self.admin_email(req)
      email = req.params.dig("admin", "email")
      email.to_s.strip.downcase.presence if email.is_a?(String)
    end

    throttle("admin-sign-in/ip", limit: 5, period: 20.seconds) do |req|
      req.ip if req.post? && req.path == ADMIN_SIGN_IN_PATH
    end

    throttle("admin-sign-in/email", limit: 10, period: 1.hour) do |req|
      admin_email(req) if req.post? && req.path == ADMIN_SIGN_IN_PATH
    end

    throttle("admin-password-reset/ip", limit: 5, period: 1.hour) do |req|
      req.ip if req.post? && req.path == ADMIN_PASSWORD_PATH
    end

    throttle("admin-password-reset/email", limit: 3, period: 1.hour) do |req|
      admin_email(req) if req.post? && req.path == ADMIN_PASSWORD_PATH
    end
  end
end

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
    #
    # The routes also answer with a format suffix (/sign_in.json, .html), so
    # match that too; an exact path match let suffixed requests skip the limits.
    def self.admin_path(name)
      %r{\A/#{Regexp.escape(Settings.admin_prefix)}/#{name}(?:\.[^/]+)?/?\z}
    end
    ADMIN_SIGN_IN_PATH = admin_path("sign_in")
    ADMIN_PASSWORD_PATH = admin_path("password")

    def self.admin_email(req)
      admin = req.params["admin"]
      email = admin["email"] if admin.is_a?(Hash)
      email.to_s.strip.downcase.presence if email.is_a?(String)
    end

    throttle("admin-sign-in/ip", limit: 5, period: 20.seconds) do |req|
      req.ip if req.post? && req.path.match?(ADMIN_SIGN_IN_PATH)
    end

    throttle("admin-sign-in/email", limit: 10, period: 1.hour) do |req|
      admin_email(req) if req.post? && req.path.match?(ADMIN_SIGN_IN_PATH)
    end

    throttle("admin-password-reset/ip", limit: 5, period: 1.hour) do |req|
      req.ip if req.post? && req.path.match?(ADMIN_PASSWORD_PATH)
    end

    throttle("admin-password-reset/email", limit: 3, period: 1.hour) do |req|
      admin_email(req) if req.post? && req.path.match?(ADMIN_PASSWORD_PATH)
    end
  end
end

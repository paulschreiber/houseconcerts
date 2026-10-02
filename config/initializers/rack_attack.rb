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
    def self.exact_path(path)
      %r{\A/#{path}(?:\.[^/]+)?/?\z}
    end
    ADMIN_SIGN_IN_PATH = exact_path("#{Regexp.escape(Settings.admin_prefix)}/sign_in")
    ADMIN_PASSWORD_PATH = exact_path("#{Regexp.escape(Settings.admin_prefix)}/password")

    # The normalized email submitted in a form (params[model][email]), or nil
    # if there isn't one or the params are malformed.
    #
    # Parsed the way Rails parses them, not with Rack's req.params: that only
    # reads form-encoded bodies, so a JSON body (which Rails, and so Devise,
    # still accepts) skipped every per-email throttle. Unparseable JSON counts
    # as no email; Rails rejects that request with a 400 anyway.
    def self.form_email(req, model)
      fields = ActionDispatch::Request.new(req.env).params[model]
      email = fields["email"] if fields.is_a?(Hash)
      email.to_s.strip.downcase.presence if email.is_a?(String)
    rescue ActionDispatch::Http::Parameters::ParseError
      nil
    end

    def self.admin_email(req) = form_email(req, "admin")

    def self.admin_sign_in?(req) = req.post? && req.path.match?(ADMIN_SIGN_IN_PATH)

    # The browser's AdminTrustedDevice id for the submitted email, or nil.
    def self.trusted_device_id(req)
      AdminTrustedDevice.device_id(ActionDispatch::Request.new(req.env), admin_email(req))
    end

    throttle("admin-sign-in/ip", limit: 5, period: 20.seconds) do |req|
      req.ip if admin_sign_in?(req)
    end

    # Browsers the admin has signed in from before skip this one, so it can't
    # be used to lock the admin out (see AdminTrustedDevice).
    throttle("admin-sign-in/email", limit: 10, period: 1.hour) do |req|
      admin_email(req) if admin_sign_in?(req) && !trusted_device_id(req)
    end

    throttle("admin-sign-in/trusted-device", limit: 10, period: 1.hour) do |req|
      trusted_device_id(req) if admin_sign_in?(req)
    end

    throttle("admin-password-reset/ip", limit: 5, period: 1.hour) do |req|
      req.ip if req.post? && req.path.match?(ADMIN_PASSWORD_PATH)
    end

    throttle("admin-password-reset/email", limit: 3, period: 1.hour) do |req|
      admin_email(req) if req.post? && req.path.match?(ADMIN_PASSWORD_PATH)
    end

    # Public forms. Each RSVP save emails the admin, and each signup can later
    # get invites, so limit bulk submissions per IP. RSVPs are also limited per
    # email, so one guest's RSVP can't be submitted over and over. The per-IP
    # limits leave room for several people sharing one network (a household,
    # an office) right after an invite goes out.
    RSVP_PATH = exact_path("rsvps")
    SIGNUP_PATH = exact_path("people")

    def self.rsvp_submission?(req) = (req.post? || req.patch?) && req.path.match?(RSVP_PATH)

    throttle("rsvp/ip", limit: 20, period: 10.minutes) do |req|
      req.ip if rsvp_submission?(req)
    end

    throttle("rsvp/email", limit: 10, period: 1.hour) do |req|
      form_email(req, "rsvp") if rsvp_submission?(req)
    end

    throttle("signup/ip", limit: 10, period: 10.minutes) do |req|
      req.ip if req.post? && req.path.match?(SIGNUP_PATH)
    end

    throttle("signup/ip/day", limit: 40, period: 1.day) do |req|
      req.ip if req.post? && req.path.match?(SIGNUP_PATH)
    end

    # Guests who hit a limit get a page saying to try again, not Rack::Attack's
    # bare "Retry later".
    THROTTLED_PAGE = Rails.public_path.join("429.html").read.freeze

    self.throttled_responder = lambda do |req|
      match = req.env["rack.attack.match_data"] || {}
      retry_after = match[:period] ? match[:period] - (match[:epoch_time] % match[:period]) : 60
      [ 429, { "content-type" => "text/html; charset=utf-8", "retry-after" => retry_after.to_s }, [ THROTTLED_PAGE ] ]
    end
  end
end

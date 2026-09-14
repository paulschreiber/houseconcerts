# Throttle repeated guesses against the uniqid-keyed public URLs (RSVP
# modify links, RSVP/mailing-list thank-you pages, unsubscribe, and the
# email open-tracking pixel) — uniqid is a random token, not a secret meant
# to withstand unlimited brute-force attempts.
module Rack
  class Attack
    throttle("uniqid-lookups/ip", limit: 20, period: 1.minute) do |req|
      req.ip if req.path.match?(%r{\A/(rsvps/(show|thanks)|list/thanks|unsubscribe|open)/})
    end
  end
end

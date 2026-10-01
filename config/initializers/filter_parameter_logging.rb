# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += %i[
  passw secret token _key crypt salt certificate otp ssn cvv cvc
]

unless defined?(Rails::Console) || Rails.env.development?
  Rails.application.config.filter_parameters += [
    :email
  ]
end

# Link tokens (uniqid) let anyone who has one view or change an RSVP, or
# unsubscribe someone, and SMS bodies are private messages, so keep both out of
# the logs. (Names and phone numbers are fine to log.)
Rails.application.config.filter_parameters += [
  :uniqid,
  /\ABody\z/ # Twilio's SMS text (TextMessagesController); /i would also match e.g. "body_html"
]

# The URL paths that carry a uniqid, as they appear in "Started GET ..." lines
# and redirect locations. The token is the path segment after the prefix.
UNIQID_IN_PATH = %r{(/(?:list/(?:thanks|rejoin)|unsubscribe|rsvps/thanks|rsvps/show/[^/"?]+|open/[^/"?]+)/)[^/"?.]+}

# "Redirected to [FILTERED]" instead of the full URL with its token.
Rails.application.config.filter_redirect << UNIQID_IN_PATH

# Rails logs each request's path ("Started GET "/unsubscribe/<token>" ..."),
# which filter_parameters doesn't touch, so replace the token there too.
module FilterUniqidFromRequestLog
  private

    def started_request_message(request)
      super.gsub(UNIQID_IN_PATH) { "#{Regexp.last_match(1)}[FILTERED]" }
    end
end
Rails::Rack::Logger.prepend(FilterUniqidFromRequestLog)

# ActiveJob logs job arguments unfiltered, and mail delivery jobs carry the
# mailer's arguments -- for NotifyMailer#text_message, the SMS body.
ActiveSupport.on_load(:action_mailer) do
  ActionMailer::MailDeliveryJob.log_arguments = false
end

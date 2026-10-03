# Receives Amazon SES events from an EventBridge API destination: permanent
# bounces and complaints, which SesEvent applies to the mailing list.
#
# An API controller (no sessions, cookies or CSRF): EventBridge authenticates
# with a shared secret in the X-SES-Events-Token header, set on the API
# destination's connection and stored as credentials.amazon.ses_events_token.
# Until that credential is set, every request is refused.
class SesEventsController < ActionController::API
  TOKEN_HEADER = "X-SES-Events-Token".freeze

  before_action :verify_token!

  def create
    SesEvent.call(JSON.parse(request.raw_post))
    head :no_content
  rescue JSON::ParserError
    head :bad_request
  end

  private

    def verify_token!
      # SES_EVENTS_TOKEN is only set by this controller's tests, so they don't
      # need the master key (CI has none). Everywhere else, the credential is
      # what's used.
      expected = ENV["SES_EVENTS_TOKEN"].presence || Rails.application.credentials.dig(:amazon, :ses_events_token)
      given = request.headers[TOKEN_HEADER].to_s
      return if expected.present? && ActiveSupport::SecurityUtils.secure_compare(given, expected)

      Rails.logger.warn("SES events: refused a request without a valid #{TOKEN_HEADER}")
      head :forbidden
    end
end

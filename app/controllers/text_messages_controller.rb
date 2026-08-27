class TextMessagesController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_twilio_signature!

  def receive
    NotifyMailer.text_message(params["From"], params["Body"]).deliver_later
  end

  private

    def verify_twilio_signature!
      # TWILIO_AUTH_TOKEN is only ever set by this controller's test suite,
      # so it doesn't depend on Rails.application.credentials being
      # decryptable — CI has no master key and can't decrypt it. Everywhere
      # else (including production), the credential is what's actually used.
      auth_token = ENV["TWILIO_AUTH_TOKEN"].presence || Rails.application.credentials.dig(:twilio, :auth_token)
      signature = request.headers["X-Twilio-Signature"]

      if auth_token.present? && signature.present?
        validator = Twilio::Security::RequestValidator.new(auth_token)
        return if validator.validate(request.original_url, request.request_parameters, signature)
      end

      head :forbidden
    end
end

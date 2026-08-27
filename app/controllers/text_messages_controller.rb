class TextMessagesController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_twilio_signature!

  def receive
    NotifyMailer.text_message(params["From"], params["Body"]).deliver_later
  end

  private

    def verify_twilio_signature!
      signature = request.headers["X-Twilio-Signature"]
      validator = Twilio::Security::RequestValidator.new(Rails.application.credentials.twilio[:auth_token])

      return if signature.present? && validator.validate(request.original_url, request.request_parameters, signature)

      head :forbidden
    end
end

# Texts a phone number through Twilio. Twilio is optional: without its
# credentials, nothing is texted and reminders go by email only. Outside
# production the message is logged instead.
class SendTextMessage
  CREDENTIALS = %i[account_sid auth_token sms_sender].freeze

  def self.enabled?(credentials = Rails.application.credentials)
    return true unless Rails.env.production?

    CREDENTIALS.all? { |name| credentials.twilio&.public_send(name).present? }
  end

  def self.call(to:, body:)
    unless Rails.env.production?
      Rails.logger.debug { "Sending SMS [#{to}]: #{body}" }
      return
    end

    twilio = Rails.application.credentials.twilio
    Twilio::REST::Client.new(twilio.account_sid, twilio.auth_token).api.account.messages.create(from: twilio.sms_sender, to:, body:)
  end
end

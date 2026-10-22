# Amazon SES (email) is required. Twilio (text messages) is optional, but
# once any of its credentials is set, all of them are.
class AssertRequiredCredentials
  def self.call(credentials = Rails.application.credentials)
    required = {
      "amazon.username" => credentials.amazon&.username,
      "amazon.password" => credentials.amazon&.password,
      "amazon.server" => credentials.amazon&.server
    }
    twilio = SendTextMessage::CREDENTIALS.to_h { |name| [ "twilio.#{name}", credentials.twilio&.public_send(name) ] }
    required.merge!(twilio) if twilio.values.any?(&:present?)

    missing = required.select { |_, value| value.blank? }.keys
    raise "Missing required credentials: #{missing.join(', ')}" if missing.any?
  end
end

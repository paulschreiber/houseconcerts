class AssertRequiredCredentials
  def self.call(credentials = Rails.application.credentials)
    required = {
      "twilio.auth_token" => credentials.twilio&.auth_token,
      "twilio.account_sid" => credentials.twilio&.account_sid,
      "twilio.sms_sender" => credentials.twilio&.sms_sender,
      "amazon.username" => credentials.amazon&.username,
      "amazon.password" => credentials.amazon&.password,
      "amazon.server" => credentials.amazon&.server
    }

    missing = required.select { |_, value| value.blank? }.keys
    raise "Missing required credentials: #{missing.join(', ')}" if missing.any?
  end
end

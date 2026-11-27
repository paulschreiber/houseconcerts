module SiteHealth
  # Text messages are optional, but once any of Twilio's credentials is set, all
  # of them are needed (see SendTextMessage). They're only used in production:
  # development logs texts instead.
  class TwilioCredentials
    def self.title
      I18n.t("site_health.twilio_credentials.title")
    end

    def self.problems(credentials = Rails.application.credentials)
      return [] unless Rails.env.production?

      values = SendTextMessage::CREDENTIALS.index_with { |name| credentials.twilio&.public_send(name) }
      return [] if values.values.none?(&:present?)

      missing = values.select { |_, value| value.blank? }.keys.map { |name| "twilio.#{name}" }
      missing.any? ? [ I18n.t("site_health.missing_credentials", names: missing.join(", ")) ] : []
    end
  end
end

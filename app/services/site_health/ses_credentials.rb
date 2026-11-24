module SiteHealth
  # Amazon SES sends the site's email. It's only used in production (see
  # config/environments/production.rb): development uses letter_opener.
  class SesCredentials
    NAMES = %w[username password server].freeze

    def self.title
      I18n.t("site_health.ses_credentials.title")
    end

    def self.problems(credentials = Rails.application.credentials)
      return [] unless Rails.env.production?

      missing = NAMES.select { |name| credentials.amazon&.public_send(name).blank? }.map { |name| "amazon.#{name}" }
      missing.any? ? [ I18n.t("site_health.missing_credentials", names: missing.join(", ")) ] : []
    end
  end
end

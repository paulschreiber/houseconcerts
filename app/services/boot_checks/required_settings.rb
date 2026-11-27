module BootChecks
  # The settings the app reads while it boots and can't change afterwards:
  # config.hosts, the mailer host and WebAuthn (organization.domain), and Active
  # Storage (storage_service). The admin prefix is read as the routes are drawn,
  # before the checks run. The defaults in config/settings.yml are neutral, so a
  # production server without its own settings.local.yml has to fail here, not
  # run as example.com. Other settings are checked elsewhere.
  class RequiredSettings
    PLACEHOLDER_DOMAIN = "example.com".freeze

    def self.problems(...)
      new(...).problems
    end

    # storage_services: the names of the services in config/storage.yml.
    def initialize(settings = Settings, storage_services: Rails.application.config.active_storage.service_configurations&.keys || [])
      @settings = settings
      @storage_services = storage_services
    end

    def problems
      problems = []
      domain = @settings.organization.domain.to_s.strip.downcase
      problems << "organization.domain is #{domain.presence || 'blank'}: set this site’s values in config/settings.local.yml" if domain.empty? || domain == PLACEHOLDER_DOMAIN
      service = @settings.storage_service.to_s
      problems << "storage_service “#{service}” isn’t in config/storage.yml" unless @storage_services.include?(service)
      problems
    end
  end
end

require "test_helper"

module BootChecks
  class RequiredSettingsTest < ActiveSupport::TestCase
    SERVICES = %w[local test].freeze
    Settings = Struct.new(:organization, :storage_service)
    Organization = Struct.new(:domain)

    def settings(domain: "concerts.example.org", storage_service: "local")
      Settings.new(Organization.new(domain), storage_service)
    end

    test "the settings are valid" do
      assert_empty RequiredSettings.problems(settings, storage_services: SERVICES)
    end

    test "rejects the placeholder domain, however it's written" do
      [ "example.com", " Example.com ", "" ].each do |domain|
        assert_equal [ "organization.domain is #{domain.strip.downcase.presence || 'blank'}: set this site’s values in config/settings.local.yml" ],
                     RequiredSettings.problems(settings(domain:), storage_services: SERVICES)
      end
    end

    test "rejects a storage service that isn't in storage.yml" do
      assert_equal [ "storage_service “amazon” isn’t in config/storage.yml" ],
                   RequiredSettings.problems(settings(storage_service: "amazon"), storage_services: SERVICES)
    end

    test "reads the defaults and the app's storage services by default" do
      assert_kind_of Array, RequiredSettings.problems
    end
  end
end

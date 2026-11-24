require "test_helper"

module BootChecks
  class RequiredSettingsTest < ActiveSupport::TestCase
    SERVICES = %w[local test].freeze

    test "the settings are valid" do
      with_setting("organization.domain", "concerts.example.org") do
        assert_empty RequiredSettings.problems(storage_services: SERVICES)
      end
    end

    test "rejects the placeholder domain, however it's written" do
      [ "example.com", " Example.com ", "" ].each do |domain|
        with_setting("organization.domain", domain) do
          assert_equal [ "organization.domain is #{domain.strip.downcase.presence || 'blank'}: set this site’s values in config/settings.local.yml" ],
                       RequiredSettings.problems(storage_services: SERVICES)
        end
      end
    end

    test "rejects a storage service that isn't in storage.yml" do
      with_setting("organization.domain", "concerts.example.org") do
        with_setting("storage_service", "amazon") do
          assert_equal [ "storage_service “amazon” isn’t in config/storage.yml" ], RequiredSettings.problems(storage_services: SERVICES)
        end
      end
    end

    test "reads the storage services from the app's configuration by default" do
      with_setting("organization.domain", "concerts.example.org") do
        assert_kind_of Array, RequiredSettings.problems
      end
    end
  end
end

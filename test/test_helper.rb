ENV["RAILS_ENV"] ||= "test"
require File.expand_path("../config/environment", __dir__)
require "rails/test_help"
require "rake"

# Rack::Attack picks up Rails.cache the first time it's used and keeps it. Pin
# it to the test environment's null store now, so a test that swaps Rails.cache
# for a real one can't leave the throttles counting across every later test.
# Tests that need throttle counters set Rack::Attack.cache.store themselves.
Rack::Attack.cache.store = Rails.cache

module ActiveSupport
  class TestCase
    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    def load_rake_tasks
      Rails.application.load_tasks unless Rake::Task.task_defined?("next_show:invite")
    end
  end
end

module ActionDispatch
  class IntegrationTest
    include Devise::Test::IntegrationHelpers
  end
end

module ActionDispatch
  class IntegrationTest
    include Devise::Test::IntegrationHelpers
  end
end

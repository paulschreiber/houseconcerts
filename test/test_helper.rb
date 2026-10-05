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

    # Replaces a class (or other object's) method with fake for the block,
    # then restores it. (Minitest's Object#stub doesn't work in this app.)
    def with_stubbed(object, name, fake)
      original = object.method(name)
      object.define_singleton_method(name, &fake)
      yield
    ensure
      object.define_singleton_method(name, original) if original
    end

    # Replaces an instance method of klass with fake for the block, then
    # restores it.
    def with_stubbed_instance_method(klass, name, fake)
      original = klass.instance_method(name)
      klass.define_method(name, &fake)
      yield
    ensure
      klass.define_method(name, original) if original
    end
  end
end

# For the batch send tests (BatchRun, its jobs, and the admin pages for them).
module BatchTestHelpers
  def show = shows(:upcoming)

  # A batch run for the upcoming show: a running invite run of one item,
  # unless overridden.
  def create_run(**attrs)
    BatchRun.create!({ show:, kind: "invite", status: "running", total_count: 1 }.merge(attrs))
  end
end

module ActionDispatch
  class IntegrationTest
    include Devise::Test::IntegrationHelpers
  end
end

require "test_helper"
require "open3"

# Boots the app in a separate process for each environment, as the console
# does. The tests boot in the test environment without eager loading, so they
# don't see a failure that only the others have.
class BootTest < ActiveSupport::TestCase
  # Production eager loads, which loads the routes before Active Storage reads
  # its draw_routes setting, so Active Storage's routes would clash with
  # config/routes.rb.
  %w[development production].each do |environment|
    test "the app boots in #{environment}" do
      # Production won't boot without its SES credentials, which CI doesn't have.
      skip "needs the credentials" if environment == "production" && Rails.application.credentials.dig(:amazon, :username).blank?

      assert_equal "booted", run_rails(environment, "puts :booted")
    end
  end

  test "the app boots with eager loading, with only the photo sizes' route from Active Storage" do
    script = "puts Rails.application.routes.named_routes.names.grep(/\\Arails_(service|disk|direct|blob)/).inspect"

    assert_equal "[:rails_blob_representation_proxy]", run_rails("test", script, "CI" => "1")
  end

  private

    # Runs the script in the environment, and returns the last line it printed.
    # SECRET_KEY_BASE_DUMMY stands in for the credentials CI doesn't have.
    def run_rails(environment, script, env = {})
      output, status = Open3.capture2e({ "RAILS_ENV" => environment, "SECRET_KEY_BASE_DUMMY" => "1" }.merge(env),
                                       Rails.root.join("bin/rails").to_s, "runner", script)
      assert_predicate status, :success?, output
      output.lines.last.strip
    end
end

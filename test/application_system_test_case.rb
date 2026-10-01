require "test_helper"

Capybara.server_host = "localhost"
Capybara.server_port = 3000
Capybara.app_host = "http://localhost:3000"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Keep the browser console log so tests can check for CSP violations.
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    options.add_option("goog:loggingPrefs", { browser: "ALL" })
  end
end

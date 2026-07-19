require "test_helper"

Capybara.server_host = "localhost"
Capybara.server_port = 3000
Capybara.app_host = "http://localhost:3000"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
end

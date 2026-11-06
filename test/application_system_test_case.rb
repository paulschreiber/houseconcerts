require "test_helper"

Capybara.server_host = "localhost"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Keep the browser console log so tests can check for CSP violations.
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    options.add_option("goog:loggingPrefs", { browser: "ALL" })
  end

  ADMIN_PASSWORD = "correct horse battery staple".freeze

  # Signs in to the admin with a password, waiting until the sign-in is done.
  def sign_in_as_admin(admin = admins(:one))
    admin.update!(password: ADMIN_PASSWORD)
    visit new_admin_session_path
    fill_in "Email", with: admin.email
    fill_in "Password", with: ADMIN_PASSWORD
    click_button "Log in"
    assert_no_current_path new_admin_session_path
  end
end

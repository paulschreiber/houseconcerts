require "application_system_test_case"

# Loads each kind of page in a real browser and fails if the Content Security
# Policy blocked anything, so a new script or stylesheet source can't break a
# page silently.
class ContentSecurityPolicyTest < ApplicationSystemTestCase
  PUBLIC_PAGES = %w[/ /about /musicians /shows /privacy /list /rsvps/show/test-upcoming-show].freeze

  setup do
    admins(:one).update!(password: "correct horse battery staple")
  end

  test "public pages and the admin sign-in page load without CSP violations" do
    (PUBLIC_PAGES + [ new_admin_session_path ]).each do |path|
      visit path
      assert_no_csp_violations path
    end
  end

  # Turbo Drive keeps the first page's CSP header, so scripts on later pages
  # only run if their nonce matches it.
  test "Turbo navigation between public pages has no CSP violations" do
    visit "/"
    assert_no_csp_violations "/"

    [ "About", "Mailing List", "Past Shows", "For Musicians", "House Concerts" ].each do |tab|
      within("#tabs") { click_link tab }
      assert_selector "#tabs li.here", text: tab
      assert_no_csp_violations "#{tab} (via Turbo)"
    end
    assert page.evaluate_script("window.Turbo !== undefined"), "Turbo didn't load"
  end

  test "admin pages load without CSP violations" do
    sign_in_as_admin

    [ madmin_root_path, madmin_rsvps_path, madmin_people_path, madmin_shows_path,
      edit_madmin_person_path(people(:one)), "/#{Settings.admin_prefix}/jobs" ].each do |path|
      visit path
      assert_no_csp_violations path
    end
  end

  private

    def sign_in_as_admin
      visit new_admin_session_path
      fill_in "Email", with: admins(:one).email
      fill_in "Password", with: "correct horse battery staple"
      click_button "Log in"
      assert_no_current_path new_admin_session_path
    end

    # Waits for the page's JavaScript to load, then checks the console log.
    def assert_no_csp_violations(path)
      assert page.evaluate_script("document.readyState") == "complete", "#{path} didn't finish loading"
      sleep 0.5 # let module scripts and their imports run
      violations = page.driver.browser.logs.get(:browser).map(&:message).grep(/Content Security Policy/)
      assert_empty violations, "CSP violations on #{path}:\n#{violations.join("\n")}"
    end
end

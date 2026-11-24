require "test_helper"

# Settings that will be editable are read when they're used, not when the app
# boots. (The admin prefix, domain and storage service stay boot-time: routes,
# Rack::Attack, config.hosts and Active Storage need them before a request.)
class SettingsReadWhenUsedTest < ActionDispatch::IntegrationTest
  test "Google Analytics' hosts are allowed in the CSP only when it's set up" do
    get about_path

    assert_includes response.headers["Content-Security-Policy"], "https://*.googletagmanager.com"

    with_setting("google_analytics_id", "") do
      get about_path
    end

    assert_not_includes response.headers["Content-Security-Policy"], "googletagmanager"
    assert_not_includes response.headers["Content-Security-Policy"], "google-analytics"
  end

  test "the site name is read for the admin pages and the passkey relying party" do
    with_setting("site_name", "Jane’s Concerts") do
      assert_equal "Jane’s Concerts", Madmin.site_name.to_s
      assert_equal "Jane’s Concerts", WebAuthn.configuration.rp_name
    end
  end
end

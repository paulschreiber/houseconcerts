require "test_helper"

module Madmin
  class SettingsControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in admins(:one)
    end

    test "the settings go to the first tab" do
      get madmin_settings_path

      assert_redirected_to madmin_setting_path("site")
    end

    test "each tab has its own form and links to the others" do
      { "site" => "settings_site_name", "email" => "settings_invites_from_email",
        "shows" => "settings_max_seats", "location" => "settings_default_country" }.each do |tab, field|
        get madmin_setting_path(tab)

        assert_response :success
        assert_select "nav.settings-tabs a", count: 4
        assert_select "nav.settings-tabs a.here[href=?]", madmin_setting_path(tab)
        assert_select "form#settings-form[action=?]", madmin_setting_path(tab) do
          assert_select "##{field}"
        end
      end
    end

    test "the site tab shows the domain as text, with no field" do
      get madmin_setting_path("site")

      assert_select ".settings-readonly", text: Defaults.organization.domain
      assert_select "input[name*=domain]", count: 0
    end

    test "the email tab shows the domain after each address" do
      get madmin_setting_path("email")

      assert_select ".settings-address .settings-unit", text: "@#{Defaults.organization.domain}", count: 2
      assert_select "input#settings_reminder_time[type=time][step='3600'][value='13:00']"
    end

    test "the email tab has the guest sign-off, as plain text over several lines" do
      get madmin_setting_path("email")

      assert_select "textarea#settings_guest_sign_off", text: ""
      assert_select "label[for=settings_guest_sign_off]", text: "Sign-off"
    end

    test "the sidebar links to the settings, after Pages and before Jobs, in its last group" do
      get madmin_setting_path("site")

      assert_select "#sidebar h4 + a[href=?] + a[href=?] + a[href=?]", madmin_pages_path, madmin_settings_path, mission_control_jobs_path
    end

    test "saving a tab stores the changes and keeps the admin on the tab" do
      patch madmin_setting_path("site"), params: { settings: { site_name: "Jane’s Concerts", meta_description: Defaults.meta_description,
                                                               meta_keywords: Defaults.meta_keywords, google_analytics_id: "G-ABC123" } }

      assert_redirected_to madmin_setting_path("site")
      assert_equal "Site settings saved.", flash[:notice]
      assert_equal "Jane’s Concerts", Settings.site_name
      assert_equal "G-ABC123", Settings.google_analytics_id
      assert_equal %w[google_analytics_id site_name], SettingValue.pluck(:key).sort
    end

    test "an unchecked box turns the RSVP notification off" do
      patch madmin_setting_path("shows"), params: { settings: shows_params.merge(notify_rsvp: "0") }

      assert_redirected_to madmin_setting_path("shows")
      assert_equal "", Settings.notify_rsvp
    end

    test "a tab with a bad value shows the error, keeps what was typed and saves nothing" do
      patch madmin_setting_path("shows"), params: { settings: shows_params.merge(max_seats: "0", duration: "5") }

      assert_response :unprocessable_content
      assert_select ".settings-number-row p.error", text: "must be greater than or equal to 1"
      assert_select "input#settings_duration[value='5']"
      assert_empty SettingValue.all
    end

    test "a bad tab doesn't stop another from saving" do
      patch madmin_setting_path("shows"), params: { settings: shows_params.merge(max_seats: "0") }
      patch madmin_setting_path("site"), params: { settings: { site_name: "Jane’s Concerts", meta_description: Defaults.meta_description,
                                                               meta_keywords: "", google_analytics_id: "" } }

      assert_redirected_to madmin_setting_path("site")
      assert_equal "Jane’s Concerts", Settings.site_name
    end

    test "an unknown tab is not found" do
      get madmin_setting_path("nonsense")

      assert_response :not_found
    end

    test "signed-out visitors are sent to sign in" do
      sign_out :admin

      get madmin_setting_path("site")

      assert_redirected_to new_admin_session_path
    end

    test "the posted settings can't include a setting that isn't on the tab" do
      patch madmin_setting_path("site"), params: { settings: { site_name: "Jane’s Concerts", meta_description: Defaults.meta_description,
                                                               meta_keywords: "", google_analytics_id: "", organization_domain: "evil.example.org", max_seats: "9" } }

      assert_equal Defaults.organization.domain, Settings.organization.domain
      assert_equal Defaults.show.max_seats, Settings.show.max_seats
    end

    private

      def shows_params
        { arrival_minutes: 30, duration: 2, availability_cutoff_hours: 8, max_seats: 4, overbook_seats: 5, waitlist_capacity: 10,
          min_price: 0, max_price: 100, min_capacity: 10, max_capacity: 100, notify_rsvp: "1" }
      end
  end
end

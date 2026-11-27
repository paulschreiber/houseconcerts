require "test_helper"

module Madmin
  class SiteHealthControllerTest < ActionDispatch::IntegrationTest
    Result = SiteHealth::Result

    setup do
      sign_in admins(:one)
    end

    test "lists every check, passed or not" do
      results = [ Result.new("Email", []), Result.new("Texts", [ "Missing credentials: twilio.auth_token." ]) ]

      with_stubbed(SiteHealth, :results, -> { results }) do
        get madmin_site_health_path
      end

      assert_response :success
      assert_select "tbody tr", count: 2
      assert_select "tbody tr:first-child td", text: "Email"
      assert_select "tbody tr:first-child td", text: "Passed"
      assert_select "tbody tr:last-child td", text: /Needs attention: Missing credentials: twilio\.auth_token\./
    end

    test "the sidebar links to the checks, after Jobs" do
      get madmin_site_health_path

      assert_select "#sidebar a[href=?]", madmin_site_health_path, text: "Site Health"
      assert_select "#sidebar a[href=?] + a[href=?]", mission_control_jobs_path, madmin_site_health_path
    end

    test "needs an admin" do
      sign_out :admin

      get madmin_site_health_path

      assert_redirected_to new_admin_session_path
    end
  end
end

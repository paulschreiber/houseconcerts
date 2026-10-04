require "test_helper"

class AdminControllerTest < ActionDispatch::IntegrationTest
  test "redirects an unauthenticated visitor to the admin login page" do
    get "/backstage/jobs"

    assert_redirected_to new_admin_session_path
  end

  test "allows an authenticated admin through" do
    sign_in admins(:one)

    get "/backstage/jobs"

    assert_response :success
  end

  test "shows the admin sidebar on the jobs page" do
    sign_in admins(:one)

    get "/backstage/jobs"

    assert_select "aside#sidebar a[href=?]", "/#{Settings.admin_prefix}", text: "Dashboard"
    assert_select "aside#sidebar a[href=?]", "/#{Settings.admin_prefix}/people", text: "People"
    assert_select "aside#sidebar a.active", text: "Jobs"
  end
end

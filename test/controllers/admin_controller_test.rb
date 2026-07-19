require "test_helper"

class AdminControllerTest < ActionDispatch::IntegrationTest
  test "redirects an unauthenticated visitor to the admin login page" do
    get "/admin/jobs"

    assert_redirected_to new_admin_session_path
  end

  test "allows an authenticated admin through" do
    sign_in admins(:one)

    get "/admin/jobs"

    assert_response :success
  end
end

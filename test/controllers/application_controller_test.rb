require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test "an already signed-in admin visiting the sign-in page is redirected to the dashboard" do
    sign_in admins(:one)

    get new_admin_session_path

    assert_redirected_to madmin_root_path
  end

  test "an already signed-in admin visiting the sign-in page is redirected to their stored deep-link target" do
    get madmin_rsvps_path # unauthenticated; Devise stores this as the post-sign-in destination
    sign_in admins(:one)

    get new_admin_session_path

    assert_redirected_to madmin_rsvps_path
  end

  test "an already signed-in admin visiting the password-reset page is not redirected to the dashboard" do
    sign_in admins(:one)

    get new_admin_password_path

    assert_redirected_to root_path
  end

  test "visiting the sign-in page after being redirected there suppresses the generic unauthenticated alert" do
    get madmin_rsvps_path # unauthenticated, redirects to sign-in with a flash alert
    follow_redirect!

    assert_response :success
    assert_no_match(/class="alert"/, response.body)
  end

  test "a failed sign-in attempt shows its alert on the sign-in page" do
    post admin_session_path, params: { admin: { email: admins(:one).email, password: "wrong password" } }

    assert_select "p.alert", text: "Invalid email or password."
  end
end

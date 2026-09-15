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
end

require "test_helper"

class AdminLoginTest < ActionDispatch::IntegrationTest
  setup do
    admins(:one).update!(password: "correct horse battery staple")
  end

  test "signs in with valid credentials and returns to the originally requested page" do
    get madmin_root_path
    assert_redirected_to new_admin_session_path

    post admin_session_path, params: {
      admin: { email: admins(:one).email, password: "correct horse battery staple" }
    }

    assert_redirected_to madmin_root_path
  end

  test "rejects invalid credentials and shows an error" do
    post admin_session_path, params: {
      admin: { email: admins(:one).email, password: "wrong password" }
    }

    assert_response :unprocessable_entity
    assert_select "p.alert", "Invalid email or password."
  end

  test "signs out and revokes access to protected pages" do
    get madmin_root_path
    post admin_session_path, params: {
      admin: { email: admins(:one).email, password: "correct horse battery staple" }
    }
    assert_redirected_to madmin_root_path

    delete destroy_admin_session_path

    get madmin_root_path
    assert_redirected_to new_admin_session_path
  end

  test "remembers the admin via a persistent cookie when remember me is checked" do
    post admin_session_path, params: {
      admin: { email: admins(:one).email, password: "correct horse battery staple", remember_me: "1" }
    }
    assert cookies["remember_admin_token"].present?

    # Simulate the browser being closed and reopened: the Rails session
    # cookie is gone, but the remember-me cookie survives and should be
    # enough on its own to authenticate the next request.
    cookies.delete("_houseconcerts_session")

    get madmin_root_path
    assert_response :success
  end

  test "does not set a remember cookie when remember me is left unchecked" do
    post admin_session_path, params: {
      admin: { email: admins(:one).email, password: "correct horse battery staple" }
    }

    assert_nil cookies["remember_admin_token"]
  end
end

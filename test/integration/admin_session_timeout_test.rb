require "test_helper"

# Admin sessions time out after a week without activity, and remember me
# doesn't outlast that.
class AdminSessionTimeoutTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery staple".freeze

  setup do
    admins(:one).update!(password: PASSWORD)
  end

  test "a session stays signed in within a week of the last request" do
    sign_in_with_password

    travel 6.days do
      get madmin_root_path

      assert_response :success
    end
  end

  test "a session is signed out after a week without activity" do
    sign_in_with_password

    travel 8.days do
      assert_signed_out
    end
  end

  test "remember me doesn't keep an admin signed in past a week" do
    sign_in_with_password(remember_me: "1")
    assert cookies["remember_admin_token"].present?

    travel 8.days do
      assert_signed_out
    end
  end

  private

    # Devise sends a timed-out request back to the page it asked for, which
    # then needs a sign-in.
    def assert_signed_out
      get madmin_root_path
      follow_redirect! if response.redirect? && response.location == madmin_root_url
      assert_redirected_to new_admin_session_path
    end

    def sign_in_with_password(remember_me: "0")
      post admin_session_path, params: { admin: { email: admins(:one).email, password: PASSWORD, remember_me: remember_me } }
      assert_response :see_other
    end
end

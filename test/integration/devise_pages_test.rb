require "test_helper"

# Devise's pages have the same margins as the site's other text pages.
class DevisePagesTest < ActionDispatch::IntegrationTest
  test "the sign in and password pages wrap their content in .pagetext" do
    get new_admin_session_path
    assert_select ".pagetext form[action=?]", admin_session_path

    get new_admin_password_path
    assert_select ".pagetext form[action=?]", admin_password_path

    token = admins(:one).send_reset_password_instructions
    get edit_admin_password_path(reset_password_token: token)
    assert_select ".pagetext form[action=?]", admin_password_path
  end

  test "the sign in page links to the forgot password page under the password field" do
    get new_admin_session_path

    assert_select ".password-field a[href=?]", new_admin_password_path, text: "Forgot your password?"
  end

  test "the sign in page loads the passkey script" do
    get new_admin_session_path

    assert_includes response.body, %(import "devise/webauthn")
  end

  test "other pages neither load nor preload the passkey script" do
    get root_path

    assert_not_includes response.body, %(import "devise/webauthn")
    assert_select "link[rel=modulepreload][href*='devise/webauthn']", count: 0
  end

  test "the passkeys page keeps Madmin's layout" do
    sign_in admins(:one)

    get admin_passkeys_path

    assert_response :success
    assert_select ".pagetext", count: 0
    assert_select "#sidebar"
  end
end

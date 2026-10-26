require "application_system_test_case"

class AdminPasskeysTest < ApplicationSystemTestCase
  include Devise::Webauthn::Test::AuthenticatorHelpers

  setup do
    @admin = admins(:one)
    @authenticator = add_virtual_authenticator
    # The test server runs on a random port; WebAuthn checks the origin.
    @allowed_origins = WebAuthn.configuration.allowed_origins
    WebAuthn.configuration.allowed_origins = [ Capybara.current_session.server.base_url ]
  end

  teardown do
    @authenticator.remove!
    WebAuthn.configuration.allowed_origins = @allowed_origins
  end

  test "signs in with a registered passkey" do
    add_passkey_to_authenticator(@authenticator, @admin)

    visit new_admin_session_path
    click_button "Log in with a passkey"

    # No "Signed in successfully." notice: Turbo reloads the page on the way
    # into Madmin's layout (different stylesheets), after the flash is used.
    assert_current_path madmin_root_path
    assert_includes page.driver.browser.manage.all_cookies.pluck(:name), "remember_admin_token"
  end

  test "adds a passkey after entering the current password" do
    @admin.update!(password: "correct horse battery staple")
    sign_in_with_password

    visit admin_passkeys_path
    fill_in "Passkey name", with: "Test laptop"
    fill_in "Password", with: "correct horse battery staple"
    click_button "Create Passkey"

    assert_text "Passkey created successfully."
    assert_selector "table.passkeys td", text: "Test laptop"
  end

  test "doesn't add a passkey with the wrong password" do
    @admin.update!(password: "correct horse battery staple")
    sign_in_with_password

    visit admin_passkeys_path
    fill_in "Passkey name", with: "Stolen session"
    fill_in "Password", with: "a guess"
    click_button "Create Passkey"

    assert_text "Enter your current password to add a passkey."
    assert_no_selector "table.passkeys"
  end

  private

    def sign_in_with_password
      visit new_admin_session_path
      fill_in "Email", with: @admin.email
      fill_in "Password", with: "correct horse battery staple"
      click_button "Log in"
      assert_no_current_path new_admin_session_path
    end
end

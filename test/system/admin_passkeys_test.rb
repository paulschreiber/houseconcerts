require "application_system_test_case"

class AdminPasskeysTest < ApplicationSystemTestCase
  include Devise::Webauthn::Test::AuthenticatorHelpers

  setup do
    @admin = admins(:one)
    @authenticator = add_virtual_authenticator
  end

  teardown do
    @authenticator.remove!
  end

  test "signs in with a registered passkey" do
    add_passkey_to_authenticator(@authenticator, @admin)

    visit new_admin_session_path
    click_button "Log in with passkeys"

    assert_current_path root_path
    assert_text "Signed in successfully."
  end
end

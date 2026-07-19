require "test_helper"
require "webauthn/fake_client"

module Admins
  class PasskeysTest < ActionDispatch::IntegrationTest
    setup do
      @admin = admins(:one)
      @client = WebAuthn::FakeClient.new(WebAuthn.configuration.allowed_origins.first, encoding: :base64url)
    end

    test "redirects to sign in when not authenticated" do
      get new_admin_passkey_path

      assert_redirected_to new_admin_session_path
    end

    test "renders the new passkey page when authenticated" do
      sign_in @admin

      get new_admin_passkey_path

      assert_response :success
    end

    test "creates a passkey with a valid credential" do
      sign_in @admin

      post admin_passkey_registration_options_path
      challenge = session[:webauthn_challenge]
      credential = @client.create(challenge: challenge, user_verified: true)

      assert_difference("@admin.passkeys.count", 1) do
        post admin_passkeys_path, params: { name: "My Passkey", public_key_credential: credential.to_json }
      end

      assert_redirected_to new_admin_passkey_path
      assert_nil session[:webauthn_challenge]
    end

    test "does not create a passkey when user verification was not performed" do
      sign_in @admin

      post admin_passkey_registration_options_path
      challenge = session[:webauthn_challenge]
      credential = @client.create(challenge: challenge, user_verified: false)

      assert_no_difference("@admin.passkeys.count") do
        post admin_passkeys_path, params: { name: "Unverified Passkey", public_key_credential: credential.to_json }
      end
    end

    test "destroys a passkey" do
      sign_in @admin
      passkey = @admin.passkeys.create!(external_id: "test-passkey-id", public_key: "test-public-key", name: "Test Passkey", sign_count: 0)

      assert_difference("@admin.passkeys.count", -1) do
        delete admin_passkey_path(passkey)
      end
    end
  end
end

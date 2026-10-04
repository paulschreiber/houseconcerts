require "test_helper"
require "webauthn/fake_client"

module Admins
  class PasskeysTest < ActionDispatch::IntegrationTest
    include ActionMailer::TestHelper

    PASSWORD = "correct horse battery staple".freeze

    setup do
      @admin = admins(:one)
      @admin.update!(password: PASSWORD)
      @client = WebAuthn::FakeClient.new(WebAuthn.configuration.allowed_origins.first, encoding: :base64url)
    end

    test "redirects to sign in when not authenticated" do
      get admin_passkeys_path

      assert_redirected_to new_admin_session_path
    end

    test "renders the passkeys page when authenticated" do
      sign_in @admin

      get admin_passkeys_path

      assert_response :success
    end

    test "the old new-passkey address redirects to the passkeys page" do
      sign_in @admin

      get new_admin_passkey_path

      assert_redirected_to admin_passkeys_path
    end

    test "creates a passkey with a valid credential" do
      sign_in @admin

      post admin_passkey_registration_options_path
      challenge = session[:webauthn_challenge]
      credential = @client.create(challenge: challenge, user_verified: true)

      assert_difference("@admin.passkeys.count", 1) do
        post admin_passkeys_path, params: { name: "My Passkey", current_password: PASSWORD, public_key_credential: credential.to_json }
      end

      assert_redirected_to admin_passkeys_path
      assert_nil session[:webauthn_challenge]
    end

    test "does not create a passkey when user verification was not performed" do
      sign_in @admin

      post admin_passkey_registration_options_path
      challenge = session[:webauthn_challenge]
      credential = @client.create(challenge: challenge, user_verified: false)

      assert_no_difference("@admin.passkeys.count") do
        post admin_passkeys_path, params: { name: "Unverified Passkey", current_password: PASSWORD, public_key_credential: credential.to_json }
      end
    end

    test "destroys a passkey" do
      sign_in @admin
      passkey = @admin.passkeys.create!(external_id: "test-passkey-id", public_key: "test-public-key", name: "Test Passkey", sign_count: 0)

      assert_difference("@admin.passkeys.count", -1) do
        delete admin_passkey_path(passkey)
      end
    end

    test "does not create a passkey without the current password" do
      sign_in @admin

      [ nil, "wrong password" ].each do |password|
        post admin_passkey_registration_options_path
        credential = @client.create(challenge: session[:webauthn_challenge], user_verified: true)

        assert_no_difference("@admin.passkeys.count") do
          post admin_passkeys_path, params: { name: "Stolen", current_password: password, public_key_credential: credential.to_json }.compact
        end
        assert_redirected_to admin_passkeys_path
        assert_equal "Enter your current password to add a passkey.", flash[:alert]
        assert_nil session[:webauthn_challenge]
      end
    end

    test "emails the admin when a passkey is added" do
      sign_in @admin
      post admin_passkey_registration_options_path
      credential = @client.create(challenge: session[:webauthn_challenge], user_verified: true)

      assert_enqueued_email_with AdminMailer, :passkey_added, args: [ @admin, "My Passkey", "127.0.0.1" ] do
        post admin_passkeys_path, params: { name: "My Passkey", current_password: PASSWORD, public_key_credential: credential.to_json }
      end
    end

    test "does not email when adding a passkey fails" do
      sign_in @admin
      post admin_passkey_registration_options_path
      credential = @client.create(challenge: session[:webauthn_challenge], user_verified: false)

      assert_no_enqueued_emails do
        post admin_passkeys_path, params: { name: "Unverified", current_password: PASSWORD, public_key_credential: credential.to_json }
      end
    end

    test "lists the admin's passkeys with a way to remove each one" do
      passkey = @admin.passkeys.create!(external_id: "listed-id", public_key: "key", name: "Laptop", sign_count: 0)
      sign_in @admin

      get admin_passkeys_path

      assert_select "table.passkeys td", text: "Laptop"
      assert_select "form[action='#{admin_passkey_path(passkey)}'] button", text: "Remove"
      assert_select "input[type=password][name=current_password][required]"
    end

    test "emails the admin when a passkey is removed" do
      sign_in @admin
      passkey = @admin.passkeys.create!(external_id: "removed-id", public_key: "key", name: "Old Phone", sign_count: 0)

      assert_enqueued_email_with AdminMailer, :passkey_removed, args: [ @admin, "Old Phone", "127.0.0.1" ] do
        delete admin_passkey_path(passkey)
      end
    end

    test "resetting the password removes every passkey" do
      @admin.passkeys.create!(external_id: "reset-1", public_key: "key", name: "Mine", sign_count: 0)
      @admin.passkeys.create!(external_id: "reset-2", public_key: "key", name: "Not mine", sign_count: 0)
      token = @admin.send_reset_password_instructions

      put admin_password_path, params: { admin: { reset_password_token: token, password: "a new password", password_confirmation: "a new password" } }

      assert_equal 0, @admin.passkeys.count
    end

    test "a failed password reset keeps the passkeys" do
      @admin.passkeys.create!(external_id: "kept", public_key: "key", name: "Mine", sign_count: 0)
      token = @admin.send_reset_password_instructions

      put admin_password_path, params: { admin: { reset_password_token: token, password: "short", password_confirmation: "short" } }

      assert_equal 1, @admin.passkeys.count
    end
  end
end

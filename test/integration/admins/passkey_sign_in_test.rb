require "test_helper"
require "webauthn/fake_client"

module Admins
  class PasskeySignInTest < ActionDispatch::IntegrationTest
    setup do
      @admin = admins(:one)
      @client = WebAuthn::FakeClient.new(WebAuthn.configuration.allowed_origins.first, encoding: :base64url)
      @admin.update!(webauthn_id: WebAuthn.generate_user_id)
      @passkey = create_passkey_for(@admin, @client)
    end

    test "signs in with a valid passkey" do
      post admin_passkey_authentication_options_path
      challenge = session[:authentication_challenge]

      assertion = generate_assertion(challenge: challenge, credential: @passkey, admin: @admin)

      assert_difference("@passkey.reload.sign_count") do
        post admin_session_path, params: { public_key_credential: assertion.to_json }
      end

      assert_redirected_to root_path
      assert_nil session[:authentication_challenge]
      follow_redirect!
      get mission_control_jobs_path
      assert_response :success
    end

    test "rejects sign-in with a non-existent credential" do
      post admin_passkey_authentication_options_path
      challenge = session[:authentication_challenge]

      assertion = generate_assertion(challenge: challenge, credential: @passkey, admin: @admin)
      @passkey.destroy!

      post admin_session_path, params: { public_key_credential: assertion.to_json }

      assert_response :success
      assert_match(/passkey/i, flash[:alert])
      get mission_control_jobs_path
      assert_redirected_to new_admin_session_path
    end

    test "rejects sign-in when the user handle is missing" do
      post admin_passkey_authentication_options_path
      challenge = session[:authentication_challenge]

      assertion = @client.get(
        challenge: challenge,
        allow_credentials: [ @passkey.external_id ],
        user_verified: true
      )

      post admin_session_path, params: { public_key_credential: assertion.to_json }

      assert_response :success
      assert_match(/passkey/i, flash[:alert])
      get mission_control_jobs_path
      assert_redirected_to new_admin_session_path
    end

    private

      def create_passkey_for(admin, client)
        challenge = WebAuthn.configuration.encoder.encode(SecureRandom.random_bytes(32))
        raw_credential = client.create(challenge: challenge, user_verified: true)
        webauthn_credential = WebAuthn::Credential.from_create(raw_credential)

        admin.passkeys.create!(
          external_id: webauthn_credential.id,
          name: "My Passkey",
          public_key: webauthn_credential.public_key,
          sign_count: webauthn_credential.sign_count
        )
      end

      def generate_assertion(challenge:, credential:, admin:)
        @client.get(
          challenge: challenge,
          allow_credentials: [ credential.external_id ],
          user_verified: true,
          user_handle: WebAuthn.configuration.encoder.decode(admin.webauthn_id)
        )
      end
  end
end

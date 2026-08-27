require "test_helper"

class TextMessagesControllerTest < ActionDispatch::IntegrationTest
  # Set via ENV rather than read from Rails.application.credentials, so these
  # tests don't depend on a master key being available (e.g. in CI).
  AUTH_TOKEN = "test-twilio-auth-token".freeze

  setup do
    @original_auth_token = ENV.fetch("TWILIO_AUTH_TOKEN", nil)
    ENV["TWILIO_AUTH_TOKEN"] = AUTH_TOKEN
  end

  teardown do
    ENV["TWILIO_AUTH_TOKEN"] = @original_auth_token
  end

  test "receive delivers a notification email when the signature is valid" do
    body = { "From" => "+15551234567", "Body" => "hello" }

    assert_emails 1 do
      post sms_url, params: body, headers: { "X-Twilio-Signature" => twilio_signature_for(sms_url, body) }
    end

    assert_response :success
  end

  test "receive rejects requests without a valid Twilio signature" do
    assert_no_emails do
      post sms_url, params: { From: "+15551234567", Body: "hello" }
    end

    assert_response :forbidden
  end

  test "receive rejects requests when no auth token is configured" do
    ENV["TWILIO_AUTH_TOKEN"] = nil

    assert_no_emails do
      post sms_url, params: { From: "+15551234567", Body: "hello" }, headers: { "X-Twilio-Signature" => "anything" }
    end

    assert_response :forbidden
  end

  private

    def twilio_signature_for(url, params)
      validator = Twilio::Security::RequestValidator.new(AUTH_TOKEN)
      validator.build_signature_for(url, params)
    end
end

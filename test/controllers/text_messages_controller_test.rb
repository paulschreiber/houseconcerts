require "test_helper"

class TextMessagesControllerTest < ActionDispatch::IntegrationTest
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

  private

    def twilio_signature_for(url, params)
      validator = Twilio::Security::RequestValidator.new(Rails.application.credentials.twilio[:auth_token])
      validator.build_signature_for(url, params)
    end
end

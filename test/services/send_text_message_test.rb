require "test_helper"

class SendTextMessageTest < ActiveSupport::TestCase
  Credentials = Struct.new(:twilio)
  Twilio = Struct.new(:auth_token, :account_sid, :sms_sender)

  test "is enabled outside production, where it logs" do
    assert SendTextMessage.enabled?(Credentials.new(nil))
  end

  test "in production, is enabled only with all of Twilio's credentials" do
    in_production do
      assert SendTextMessage.enabled?(Credentials.new(Twilio.new("token", "sid", "+15551234567")))
      assert_not SendTextMessage.enabled?(Credentials.new(nil))
      assert_not SendTextMessage.enabled?(Credentials.new(Twilio.new("token", nil, "+15551234567")))
    end
  end
end

require "test_helper"

module SiteHealth
  class TwilioCredentialsTest < ActiveSupport::TestCase
    Credentials = Struct.new(:twilio)
    Twilio = Struct.new(:auth_token, :account_sid, :sms_sender)

    test "has no problems when all credentials are present" do
      in_production do
        assert_empty TwilioCredentials.problems(Credentials.new(Twilio.new("token", "sid", "+15551234567")))
      end
    end

    test "has no problems without Twilio, which is optional" do
      in_production do
        assert_empty TwilioCredentials.problems(Credentials.new(nil))
        assert_empty TwilioCredentials.problems(Credentials.new(Twilio.new(nil, "", nil)))
      end
    end

    test "lists the rest of a partial setup" do
      in_production do
        assert_equal [ "Missing credentials: twilio.account_sid, twilio.sms_sender." ],
                     TwilioCredentials.problems(Credentials.new(Twilio.new("token", nil, "")))
      end
    end

    test "checks nothing outside production" do
      assert_empty TwilioCredentials.problems(Credentials.new(Twilio.new("token", nil, nil)))
    end
  end
end

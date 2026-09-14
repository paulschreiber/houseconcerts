require "test_helper"

class AssertRequiredCredentialsTest < ActiveSupport::TestCase
  Credentials = Struct.new(:twilio, :amazon)
  Twilio = Struct.new(:auth_token, :account_sid, :sms_sender)
  Amazon = Struct.new(:username, :password, :server)

  test "passes when all required credentials are present" do
    credentials = Credentials.new(
      Twilio.new("token", "sid", "+15551234567"),
      Amazon.new("user", "pass", "smtp.example.com")
    )

    assert_nothing_raised { AssertRequiredCredentials.call(credentials) }
  end

  test "raises listing every missing credential" do
    credentials = Credentials.new(
      Twilio.new(nil, "sid", nil),
      Amazon.new("user", nil, "smtp.example.com")
    )

    error = assert_raises(RuntimeError) { AssertRequiredCredentials.call(credentials) }

    assert_match(/twilio\.auth_token/, error.message)
    assert_match(/twilio\.sms_sender/, error.message)
    assert_match(/amazon\.password/, error.message)
    assert_no_match(/twilio\.account_sid/, error.message)
    assert_no_match(/amazon\.username/, error.message)
  end

  test "raises when a credential group is entirely missing" do
    credentials = Credentials.new(nil, nil)

    error = assert_raises(RuntimeError) { AssertRequiredCredentials.call(credentials) }

    assert_match(/twilio\.auth_token/, error.message)
    assert_match(/twilio\.account_sid/, error.message)
    assert_match(/twilio\.sms_sender/, error.message)
    assert_match(/amazon\.username/, error.message)
  end
end

require "test_helper"

class AssertRequiredCredentialsTest < ActiveSupport::TestCase
  Credentials = Struct.new(:twilio, :amazon)
  Twilio = Struct.new(:auth_token, :account_sid, :sms_sender)
  Amazon = Struct.new(:username, :password, :server)

  def amazon
    Amazon.new("user", "pass", "smtp.example.com")
  end

  test "passes when all credentials are present" do
    credentials = Credentials.new(Twilio.new("token", "sid", "+15551234567"), amazon)

    assert_nothing_raised { AssertRequiredCredentials.call(credentials) }
  end

  test "passes without Twilio, which is optional" do
    assert_nothing_raised { AssertRequiredCredentials.call(Credentials.new(nil, amazon)) }
    assert_nothing_raised { AssertRequiredCredentials.call(Credentials.new(Twilio.new(nil, nil, nil), amazon)) }
  end

  test "raises listing every missing credential, including the rest of a partial Twilio setup" do
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

  test "raises when Amazon is missing" do
    error = assert_raises(RuntimeError) { AssertRequiredCredentials.call(Credentials.new(nil, nil)) }

    assert_match(/amazon\.username/, error.message)
    assert_match(/amazon\.password/, error.message)
    assert_match(/amazon\.server/, error.message)
    assert_no_match(/twilio/, error.message)
  end
end

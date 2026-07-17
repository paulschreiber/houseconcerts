require "test_helper"

class TextMessagesControllerTest < ActionDispatch::IntegrationTest
  test "receive delivers a notification email" do
    assert_emails 1 do
      post sms_url, params: { From: "+15551234567", Body: "hello" }
    end

    assert_response :success
  end
end

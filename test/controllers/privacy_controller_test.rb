require "test_helper"

class PrivacyControllerTest < ActionDispatch::IntegrationTest
  test "index renders successfully" do
    get privacy_path

    assert_response :success
    assert_includes response.body, "text message reminders"
  end

  test "index doesn't mention text messages when they aren't set up" do
    with_stubbed(SendTextMessage, :enabled?, -> { false }) do
      get privacy_path
    end

    assert_includes response.body, "Phone numbers you submit are only used to contact you about that specific show."
    assert_not_includes response.body, "text message"
  end
end

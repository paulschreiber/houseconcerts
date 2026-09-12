require "test_helper"

class PrivacyControllerTest < ActionDispatch::IntegrationTest
  test "index renders successfully" do
    get privacy_path

    assert_response :success
  end
end

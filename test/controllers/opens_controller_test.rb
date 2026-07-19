require "test_helper"

class OpensControllerTest < ActionDispatch::IntegrationTest
  test "records an open when a known uniqid and tag are given" do
    person = people(:one)

    assert_difference("Open.count", 1) do
      get open_tracking_path(tag: "test-show:invite", uniqid: person.uniqid)
    end

    open = Open.last
    assert_equal person.email, open.email
    assert_equal "test-show:invite", open.tag
    assert open.open
  end

  test "does not record an open for an unknown uniqid" do
    assert_no_difference("Open.count") do
      get open_tracking_path(tag: "test-show:invite", uniqid: "nonexistent")
    end

    assert_response :success
  end

  test "always returns a blank gif" do
    get open_tracking_path(tag: "test-show:invite", uniqid: "nonexistent")

    assert_response :success
    assert_equal "image/gif", @response.media_type
  end
end

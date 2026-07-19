require "test_helper"

class ShowsControllerTest < ActionDispatch::IntegrationTest
  test "index lists upcoming shows" do
    get root_path

    assert_response :success
    assert_select "h2", text: shows(:upcoming).name
  end

  test "index shows a message when there are no upcoming shows" do
    Show.update_all(status: "cancelled") # rubocop:disable Rails/SkipsModelValidations

    get root_path

    assert_response :success
    assert_select "h2", text: "No shows scheduled"
  end

  test "shows lists past shows" do
    get past_shows_path

    assert_response :success
  end

  test "shows shows a message when there are no past shows" do
    Show.update_all(status: "cancelled") # rubocop:disable Rails/SkipsModelValidations

    get past_shows_path

    assert_response :success
    assert_select "h2", text: "No shows found"
  end

  test "ical returns a blank success response" do
    get "/calendar/ical"

    assert_response :success
    assert_empty @response.body
  end

  test "about renders the about page" do
    get about_path

    assert_response :success
  end

  test "musicians renders the musician info page" do
    get musicians_path

    assert_response :success
  end
end

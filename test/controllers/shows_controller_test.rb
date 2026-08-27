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

  test "calendar returns an ics feed of upcoming shows" do
    get calendar_path

    assert_response :success
    assert_equal "text/calendar", @response.media_type
    assert_includes @response.body, "BEGIN:VCALENDAR"
    assert_includes @response.body, "SUMMARY:#{shows(:upcoming).name} House Concert"
  end

  test "calendar excludes past shows" do
    get calendar_path

    assert_response :success
    assert_not_includes @response.body, "SUMMARY:#{shows(:past).name} House Concert"
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

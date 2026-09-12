require "test_helper"

module Madmin
  class ShowsControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in admins(:one)
    end

    test "index renders successfully" do
      get madmin_shows_path

      assert_response :success
    end

    test "show renders successfully" do
      get madmin_show_path(shows(:upcoming))

      assert_response :success
    end

    test "edit renders successfully" do
      get edit_madmin_show_path(shows(:upcoming))

      assert_response :success
    end

    test "new renders successfully" do
      get new_madmin_show_path

      assert_response :success
    end

    test "create creates a show and redirects to its show page" do
      start = 2.months.from_now.change(hour: 19, min: 0, sec: 0)

      assert_difference "Show.count", 1 do
        post madmin_shows_path, params: { show: {
          name: "New Show", venue_id: venues(:one).id, price: 20,
          start: start.iso8601, end: (start + 2.hours).iso8601
        } }
      end

      assert_redirected_to madmin_show_path(Show.last)
    end

    test "create with invalid attributes renders new" do
      assert_no_difference "Show.count" do
        post madmin_shows_path, params: { show: { name: "", start: 2.months.from_now.iso8601, venue_id: venues(:one).id, price: 20 } }
      end

      assert_response :unprocessable_content
    end

    test "update updates the show and redirects to its show page" do
      show = shows(:upcoming)

      patch madmin_show_path(show), params: { show: { name: "Updated Show" } }

      assert_equal "Updated Show", show.reload.name
      assert_redirected_to madmin_show_path(show)
    end

    test "update with invalid attributes renders edit" do
      show = shows(:upcoming)

      patch madmin_show_path(show), params: { show: { name: "" } }

      assert_response :unprocessable_content
      assert_equal "Test Upcoming Show", show.reload.name
    end

    test "destroy destroys the show and redirects to the index page" do
      show = shows(:past)

      assert_difference "Show.count", -1 do
        delete madmin_show_path(show)
      end

      assert_redirected_to madmin_shows_path
    end
  end
end

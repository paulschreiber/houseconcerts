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

    test "upcoming scope sorts shows by start ascending by default" do
      soon = Show.create!(name: "Soon Show", venue: venues(:one), price: 20, start: 1.day.from_now, end: 1.day.from_now + 2.hours)
      later = Show.create!(name: "Later Show", venue: venues(:one), price: 20, start: 10.days.from_now, end: 10.days.from_now + 2.hours)
      # created_at ties (same-second precision) would otherwise make this
      # pass by coincidence via insertion-order tiebreaking; force created_at
      # into the opposite order of start so this only passes if the
      # controller actually sorts by start.
      soon.update_column(:created_at, 1.hour.ago) # rubocop:disable Rails/SkipsModelValidations
      later.update_column(:created_at, 1.hour.from_now) # rubocop:disable Rails/SkipsModelValidations

      get madmin_shows_path(scope: "upcoming")

      assert_response :success
      assert_operator response.body.index(soon.name), :<, response.body.index(later.name)
    end

    test "past scope sorts shows by start descending by default" do
      older = Show.create!(name: "Older Show", venue: venues(:one), price: 20, start: 10.days.ago, end: 10.days.ago + 2.hours)
      recent = Show.create!(name: "Recent Show", venue: venues(:one), price: 20, start: 1.day.ago, end: 1.day.ago + 2.hours)
      # created_at ties (same-second precision) would otherwise make this
      # depend on incidental insertion-order tiebreaking; force created_at
      # into the opposite order of start so this only passes if the
      # controller actually sorts by start.
      older.update_column(:created_at, 1.hour.from_now) # rubocop:disable Rails/SkipsModelValidations
      recent.update_column(:created_at, 1.hour.ago) # rubocop:disable Rails/SkipsModelValidations

      get madmin_shows_path(scope: "past")

      assert_response :success
      assert_operator response.body.index(recent.name), :<, response.body.index(older.name)
    end

    test "the all (no scope) view sorts shows by start descending by default" do
      older = Show.create!(name: "Older Show", venue: venues(:one), price: 20, start: 10.days.ago, end: 10.days.ago + 2.hours)
      recent = Show.create!(name: "Recent Show", venue: venues(:one), price: 20, start: 1.day.ago, end: 1.day.ago + 2.hours)
      # created_at ties (same-second precision) would otherwise make this
      # depend on incidental insertion-order tiebreaking; force created_at
      # into the opposite order of start so this only passes if the
      # controller actually sorts by start.
      older.update_column(:created_at, 1.hour.from_now) # rubocop:disable Rails/SkipsModelValidations
      recent.update_column(:created_at, 1.hour.ago) # rubocop:disable Rails/SkipsModelValidations

      get madmin_shows_path

      assert_response :success
      assert_operator response.body.index(recent.name), :<, response.body.index(older.name)
    end

    test "an explicit sort param overrides the scope's default ordering" do
      Show.create!(name: "Soon Show", venue: venues(:one), price: 20, start: 1.day.from_now, end: 1.day.from_now + 2.hours)
      Show.create!(name: "Later Show", venue: venues(:one), price: 20, start: 10.days.from_now, end: 10.days.from_now + 2.hours)

      get madmin_shows_path(scope: "upcoming", sort: "start", direction: "desc")

      assert_response :success
      assert_operator response.body.index("Later Show"), :<, response.body.index("Soon Show")
    end

    test "ShowResource's default sort hooks match the actual default ordering" do
      assert_equal "start", ShowResource.default_sort_column
      assert_equal "desc", ShowResource.default_sort_direction
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

require "test_helper"

module Madmin
  class VenuesControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in admins(:one)
    end

    test "index renders successfully" do
      get madmin_venues_path

      assert_response :success
    end

    test "show renders successfully" do
      get madmin_venue_path(venues(:one))

      assert_response :success
    end

    test "edit renders successfully" do
      get edit_madmin_venue_path(venues(:one))

      assert_response :success
    end

    test "new renders successfully" do
      get new_madmin_venue_path

      assert_response :success
    end

    test "create creates a venue and redirects to its show page" do
      assert_difference "Venue.count", 1 do
        post madmin_venues_path, params: { venue: {
          name: "New Venue", address: "456 Side St", city: "Brooklyn", province: "NY",
          postcode: "11201", country: "US", capacity: 40
        } }
      end

      assert_redirected_to madmin_venue_path(Venue.last)
    end

    test "create with invalid attributes renders new" do
      assert_no_difference "Venue.count" do
        post madmin_venues_path, params: { venue: { name: "" } }
      end

      assert_response :unprocessable_content
    end

    test "update updates the venue and redirects to its show page" do
      venue = venues(:one)

      patch madmin_venue_path(venue), params: { venue: { name: "Updated Venue" } }

      assert_equal "Updated Venue", venue.reload.name
      assert_redirected_to madmin_venue_path(venue)
    end

    test "update with invalid attributes renders edit" do
      venue = venues(:one)

      patch madmin_venue_path(venue), params: { venue: { name: "" } }

      assert_response :unprocessable_content
      assert_equal "Test Venue", venue.reload.name
    end

    test "destroy destroys the venue and redirects to the index page" do
      venue = venues(:one)

      assert_difference "Venue.count", -1 do
        delete madmin_venue_path(venue)
      end

      assert_redirected_to madmin_venues_path
    end
  end
end

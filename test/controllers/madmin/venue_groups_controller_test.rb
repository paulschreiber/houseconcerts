require "test_helper"

module Madmin
  class VenueGroupsControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in admins(:one)
    end

    test "index renders successfully" do
      get madmin_venue_groups_path

      assert_response :success
    end

    test "show renders successfully" do
      get madmin_venue_group_path(venue_groups(:one))

      assert_response :success
    end

    test "edit renders successfully" do
      get edit_madmin_venue_group_path(venue_groups(:one))

      assert_response :success
    end

    test "new renders successfully" do
      get new_madmin_venue_group_path

      assert_response :success
    end

    test "create creates a venue group and redirects to its show page" do
      assert_difference "VenueGroup.count", 1 do
        post madmin_venue_groups_path, params: { venue_group: { name: "New Venue Group" } }
      end

      assert_redirected_to madmin_venue_group_path(VenueGroup.last)
    end

    test "create with invalid attributes renders new" do
      assert_no_difference "VenueGroup.count" do
        post madmin_venue_groups_path, params: { venue_group: { name: "" } }
      end

      assert_response :unprocessable_content
    end

    test "update updates the venue group and redirects to its show page" do
      venue_group = venue_groups(:one)

      patch madmin_venue_group_path(venue_group), params: { venue_group: { name: "Updated Venue Group" } }

      assert_equal "Updated Venue Group", venue_group.reload.name
      assert_redirected_to madmin_venue_group_path(venue_group)
    end

    test "update with invalid attributes renders edit" do
      venue_group = venue_groups(:one)

      patch madmin_venue_group_path(venue_group), params: { venue_group: { name: "" } }

      assert_response :unprocessable_content
      assert_equal "Test Group One", venue_group.reload.name
    end

    test "destroy destroys the venue group and redirects to the index page" do
      venue_group = venue_groups(:one)

      assert_difference "VenueGroup.count", -1 do
        delete madmin_venue_group_path(venue_group)
      end

      assert_redirected_to madmin_venue_groups_path
    end
  end
end

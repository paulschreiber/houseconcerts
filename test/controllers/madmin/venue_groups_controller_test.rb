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
  end
end

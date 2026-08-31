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
  end
end

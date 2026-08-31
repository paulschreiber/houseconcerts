require "test_helper"

module Madmin
  class ArtistsControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in admins(:one)
    end

    test "index renders successfully" do
      get madmin_artists_path

      assert_response :success
    end

    test "show renders successfully" do
      get madmin_artist_path(artists(:one))

      assert_response :success
    end

    test "edit renders successfully" do
      get edit_madmin_artist_path(artists(:one))

      assert_response :success
    end

    test "new renders successfully" do
      get new_madmin_artist_path

      assert_response :success
    end
  end
end

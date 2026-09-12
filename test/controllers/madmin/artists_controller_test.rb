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

    test "create creates an artist and redirects to its show page" do
      assert_difference "Artist.count", 1 do
        post madmin_artists_path, params: { artist: { name: "New Artist", url: "https://example.com/new-artist" } }
      end

      assert_redirected_to madmin_artist_path(Artist.last)
    end

    test "create with invalid attributes renders new" do
      assert_no_difference "Artist.count" do
        post madmin_artists_path, params: { artist: { name: "" } }
      end

      assert_response :unprocessable_content
    end

    test "update updates the artist and redirects to its show page" do
      artist = artists(:one)

      patch madmin_artist_path(artist), params: { artist: { name: "Updated Artist" } }

      assert_equal "Updated Artist", artist.reload.name
      assert_redirected_to madmin_artist_path(artist)
    end

    test "update with invalid attributes renders edit" do
      artist = artists(:one)

      patch madmin_artist_path(artist), params: { artist: { name: "" } }

      assert_response :unprocessable_content
      assert_equal "Test Artist", artist.reload.name
    end

    test "destroy destroys the artist and redirects to the index page" do
      artist = artists(:one)

      assert_difference "Artist.count", -1 do
        delete madmin_artist_path(artist)
      end

      assert_redirected_to madmin_artists_path
    end
  end
end

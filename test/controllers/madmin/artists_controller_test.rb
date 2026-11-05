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

    test "update attaches an uploaded photo" do
      artist = artists(:one)

      patch madmin_artist_path(artist), params: { artist: { photo: fixture_file_upload("photo.heic", "image/heic") } }

      assert_redirected_to madmin_artist_path(artist)
      assert_equal "photo.jpg", artist.reload.photo.filename.to_s
    end

    test "update replaces the artist's photo" do
      artist = attach_photo(artists(:one))
      old_blob = artist.photo.blob

      patch madmin_artist_path(artist), params: { artist: { photo: fixture_file_upload("photo.webp", "image/webp") } }

      assert_not_equal old_blob, artist.reload.photo.blob
    end

    test "update without a new photo keeps the artist's photo" do
      artist = attach_photo(artists(:one))

      patch madmin_artist_path(artist), params: { artist: { name: "Jane Smith" } }

      assert artist.reload.photo.attached?
    end

    test "update refuses a PNG photo with a message" do
      artist = artists(:one)

      patch madmin_artist_path(artist), params: { artist: { photo: fixture_file_upload("png_named.jpg", "image/jpeg") } }

      assert_response :unprocessable_content
      assert_select ".alert li", text: "Choose a JPEG, HEIC, AVIF or WebP photo"
      assert_not artist.reload.photo.attached?
    end

    test "update refusing a new photo keeps the artist's saved one" do
      artist = attach_photo(artists(:one))

      patch madmin_artist_path(artist), params: { artist: { photo: fixture_file_upload("tiny.jpg", "image/jpeg") } }

      assert_response :unprocessable_content
      assert_select ".alert li", text: "Choose a photo at least 400 × 440 pixels"
      assert_equal "photo.jpg", artist.reload.photo.filename.to_s
    end

    test "edit offers the photo formats and describes the limits" do
      get edit_madmin_artist_path(artists(:one))

      assert_select "input[type=file][name='artist[photo]'][accept=?]", Artist::PHOTO_CONTENT_TYPES.join(",")
      assert_select ".form-description", text: /at least 400 × 440 pixels, at most 50 megapixels and smaller than 10 MB/
    end

    test "show and index show the photo's card and thumb sizes" do
      artist = attach_photo(artists(:one))

      get madmin_artist_path(artist)
      assert_select "img[src*='/representations/proxy/'][width='200']"
      assert_select "img[src*='/blobs/']", false

      get madmin_artists_path
      assert_select "img[src*='/representations/proxy/'][width='50']"
    end

    test "the photo's Remove link deletes it and returns to the artist" do
      artist = attach_photo(artists(:one))
      attachment = artist.photo.attachment

      get madmin_artist_path(artist)
      assert_select "a[href=?][data-turbo-method=delete]", madmin_active_storage_attachment_path(attachment), text: "Remove"

      delete madmin_active_storage_attachment_path(attachment)

      assert_redirected_to madmin_artist_path(artist)
      assert_not artist.reload.photo.attached?
    end

    test "removing a photo needs an admin" do
      artist = attach_photo(artists(:one))
      sign_out :admin

      delete madmin_active_storage_attachment_path(artist.photo.attachment)

      assert artist.reload.photo.attached?
    end
  end
end

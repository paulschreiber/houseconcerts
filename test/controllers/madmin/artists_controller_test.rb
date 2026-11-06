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
      assert_equal "#{artist.slug}.jpg", artist.reload.photo.filename.to_s
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
      assert_select ".alert li", text: "the photo must be a JPEG, HEIC, AVIF or WebP file"
      assert_not artist.reload.photo.attached?
    end

    test "update refusing a new photo keeps the artist's saved one" do
      artist = attach_photo(artists(:one))
      saved = artist.photo.blob

      patch madmin_artist_path(artist), params: { artist: { photo: fixture_file_upload("tiny.jpg", "image/jpeg") } }

      assert_response :unprocessable_content
      assert_select ".alert", text: /\APlease correct the following errors:/
      assert_select ".alert li", text: "the photo must be at least 400 pixels wide"
      assert_select ".alert li", text: "the photo must be at least 440 pixels tall"
      assert_select "form[enctype='multipart/form-data'] input[type=file][name='artist[photo]'][id=artist_photo]"
      assert_select "p.error", false
      assert_select "img[src*='/representations/proxy/'][alt=?]", artist.name
      assert_select "a[href=?]", madmin_active_storage_attachment_path(artist.photo.attachment), text: "Remove"
      assert_equal saved, artist.reload.photo.blob
    end

    test "after a refused name, the photo and its Remove link use the saved name" do
      artist = attach_photo(artists(:one))

      patch madmin_artist_path(artist), params: { artist: { name: "" } }

      assert_response :unprocessable_content
      assert_select "img[src*='/representations/proxy/'][alt=?]", artist.name
      assert_select "a[data-turbo-confirm=?]", "Are you sure you want to delete the photo for #{artist.name}?"
    end

    test "edit offers the photo formats and describes the limits" do
      get edit_madmin_artist_path(artists(:one))

      assert_select "input[type=file][name='artist[photo]'][accept=?]", Artist::PHOTO_CONTENT_TYPES.join(",")
      assert_select ".form-description", text: /at least 400 × 440 pixels, at most 50 megapixels and smaller than 10 MB/
    end

    test "show shows the photo's card size, and index leaves the photo out" do
      artist = attach_photo(artists(:one))

      get madmin_artist_path(artist)
      assert_select "img[src*='/representations/proxy/'][width='200']"
      assert_select "img[src*='/blobs/']", false

      get madmin_artists_path
      assert_select "img[src*='/representations/proxy/']", false
    end

    test "the edit form shows the photo above the file input, with a Remove link that deletes it and returns to the form" do
      artist = attach_photo(artists(:one))
      attachment = artist.photo.attachment

      get madmin_artist_path(artist)
      assert_select "a[href=?]", madmin_active_storage_attachment_path(attachment), false

      get edit_madmin_artist_path(artist)
      assert_select ".photo-field-current + input[type=file][name='artist[photo]']"
      assert_select "a[href=?][data-turbo-method=delete][data-turbo-confirm=?]", madmin_active_storage_attachment_path(attachment),
                    "Are you sure you want to delete the photo for #{artist.name}?", text: "Remove"

      delete madmin_active_storage_attachment_path(attachment)

      assert_redirected_to edit_madmin_artist_path(artist)
      assert_not artist.reload.photo.attached?
    end

    test "removing a photo with Turbo takes it off the edit form in place" do
      artist = attach_photo(artists(:one))
      photo_id = ActionView::RecordIdentifier.dom_id(artist, :photo)

      get edit_madmin_artist_path(artist)
      assert_select "##{photo_id} img"

      delete madmin_active_storage_attachment_path(artist.photo.attachment), as: :turbo_stream

      assert_response :success
      assert_equal "text/vnd.turbo-stream.html", response.media_type
      assert_select "turbo-stream[action=remove][target=?]", photo_id
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

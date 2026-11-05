require "test_helper"

# Only photo sizes are served: Active Storage's own routes, which would serve
# the stored photo itself to anyone with a photo size's URL, are off
# (config.active_storage.draw_routes).
class ArtistPhotoUrlsTest < ActionDispatch::IntegrationTest
  test "a resized photo's URL serves it as a JPEG" do
    artist = attach_photo(artists(:one))

    get Rails.application.routes.url_helpers.polymorphic_path(artist.photo.variant(:card))

    assert_response :success
    assert_equal "image/jpeg", response.media_type
  end

  test "the original file isn't served, even with a resized photo's signed id" do
    blob = attach_photo(artists(:one)).photo.blob

    %w[blobs/proxy blobs/redirect blobs].each do |path|
      get "/rails/active_storage/#{path}/#{blob.signed_id}/photo.jpg"

      assert_response :not_found, path
    end
  end

  test "direct uploads aren't accepted" do
    post "/rails/active_storage/direct_uploads", params: { blob: { filename: "photo.jpg", byte_size: 1, checksum: "x", content_type: "image/jpeg" } }

    assert_response :not_found
  end
end

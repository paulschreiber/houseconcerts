require "test_helper"

class ArtistPhotosHelperTest < ActionView::TestCase
  PROXY_URL = %r{\Ahttp://[^/]+/rails/active_storage/representations/proxy/.+/test-artist\.jpg\z}

  test "artist_photo_tag shows an uploaded photo at half its image's size" do
    artist = attach_photo(artists(:one))

    img = Nokogiri::HTML5.fragment(artist_photo_tag(artist, :card, class: "artist")).at_css("img")

    assert_match PROXY_URL, img["src"]
    assert_equal([ "200", "220", artist.name, "artist" ], %w[width height alt class].map { |name| img[name] })
  end

  test "artist_photo_tag is nil, and artist_photo? false, for an artist without a photo" do
    assert_nil artist_photo_tag(artists(:one), :card)
    assert_not artist_photo?(artists(:one))
  end

  test "artist_photo_url is the uploaded photo's social size, or nil without one" do
    assert_nil artist_photo_url(artists(:one))

    assert_match PROXY_URL, artist_photo_url(attach_photo(artists(:one)))
  end
end

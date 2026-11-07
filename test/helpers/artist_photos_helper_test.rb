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
    with_public_path do
      assert_nil artist_photo_tag(artists(:one), :card)
      assert_not artist_photo?(artists(:one), :card)
    end
  end

  test "artist_photo_url is the uploaded photo's social size, or nil without one" do
    with_public_path do
      assert_nil artist_photo_url(artists(:one))

      assert_match PROXY_URL, artist_photo_url(attach_photo(artists(:one)))
    end
  end

  test "an artist without an uploaded photo falls back to their file in public/photos/headshots" do
    artist = artists(:one)
    with_public_path("photos/headshots/#{artist.slug}.jpg") do
      assert artist_photo?(artist, :card)
      assert_not artist_photo?(artist, :thumb)
      assert_equal "/photos/headshots/#{artist.slug}.jpg", Nokogiri::HTML5.fragment(artist_photo_tag(artist, :card)).at_css("img")["src"]
      assert_equal "#{root_url}photos/headshots/#{artist.slug}.jpg", artist_photo_url(artist)
    end
  end

  private

    # Runs the block with public/ as an empty directory holding only the
    # given files.
    def with_public_path(*files, &)
      Dir.mktmpdir do |dir|
        files.each { |file| FileUtils.mkdir_p(File.dirname(File.join(dir, file))) && FileUtils.touch(File.join(dir, file)) }
        with_stubbed(Rails, :public_path, -> { Pathname(dir) }, &)
      end
    end
end

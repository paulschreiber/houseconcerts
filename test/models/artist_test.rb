require "test_helper"

class ArtistTest < ActiveSupport::TestCase
  test "fixture is valid" do
    assert artists(:one).valid?
  end

  test "requires a name" do
    artist = Artist.new(artists(:one).attributes.except("id").merge("name" => ""))
    assert_not artist.valid?
    assert_includes artist.errors.attribute_names, :name
  end

  test "saves with a url" do
    artist = Artist.new(name: "Artist With URL", url: "https://example.com/artist")
    assert artist.save
  end

  test "saves without a url" do
    artist = Artist.new(name: "Artist Without URL", url: "")
    assert artist.save
  end

  test "fails to save with an invalid url" do
    artist = Artist.new(name: "Artist With Bad URL", url: "not a url")
    assert_not artist.save
    assert_includes artist.errors.attribute_names, :url
  end

  test "photo is derived from the slug" do
    assert_equal "photos/headshots/#{artists(:one).slug}.jpg", artists(:one).photo
  end

  test "shows association resolves through artist_shows" do
    assert_includes artists(:one).shows, shows(:upcoming)
  end

  test "adding a show creates the join record" do
    artist = Artist.create!(name: "New Artist", url: "https://example.com/new-artist")

    assert_difference("ArtistShow.count", 1) do
      artist.shows << shows(:past)
    end
    assert_includes artist.shows, shows(:past)
  end
end

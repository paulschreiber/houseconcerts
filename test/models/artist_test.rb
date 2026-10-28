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

  test "invite_messages are ordered by show date, then revision" do
    artist = artists(:one)
    artist.shows << shows(:past)
    # Created out of order, so the ids don't match the expected order.
    upcoming_second = new_revision(shows(:upcoming))
    past_first = new_revision(shows(:past))
    past_second = new_revision(shows(:past))
    expected = [ past_first, past_second, invite_messages(:upcoming), upcoming_second ]

    assert_equal expected, artist.invite_messages.to_a
    assert_equal expected, Artist.preload(:invite_messages).find(artist.id).invite_messages.to_a
  end

  test "invite_messages keep each show's revisions together when shows start at the same time" do
    artist = artists(:one)
    same_start = shows(:upcoming).dup.tap { |show| show.update!(slug: nil, name: "Same Start Show") }
    artist.shows << same_start
    later_show_first = new_revision(same_start)
    upcoming_second = new_revision(shows(:upcoming))

    assert_equal [ invite_messages(:upcoming), upcoming_second, later_show_first ], artist.invite_messages.to_a
  end

  private

    def new_revision(show)
      show.invite_messages.create!(intro: "Intro", about: "About")
    end
end

require "test_helper"

class ArtistShowTest < ActiveSupport::TestCase
  test "rejects a duplicate artist/show pairing" do
    existing = artist_shows(:one)
    duplicate = ArtistShow.new(artist_id: existing.artist_id, show_id: existing.show_id)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:artist_id], "has already been taken"
  end

  test "allows the same artist on a different show" do
    existing = artist_shows(:one)
    other_show = shows(:sold_out)

    assert ArtistShow.new(artist_id: existing.artist_id, show_id: other_show.id).valid?
  end
end

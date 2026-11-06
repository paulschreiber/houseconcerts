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

  %w[photo.jpg photo.heic photo.avif photo.webp].each do |file|
    test "accepts a #{File.extname(file)} photo" do
      artist = artists(:one)
      artist.photo.attach(io: file_fixture(file).open, filename: file)

      assert artist.valid?, artist.errors.full_messages.to_sentence
    end
  end

  test "rejects a PNG photo, even one named .jpg" do
    %w[photo.png png_named.jpg].each do |file|
      artist = Artist.new(name: "Jane Smith", photo: { io: file_fixture(file).open, filename: file })

      assert_not artist.valid?
      assert_equal [ "the photo must be a JPEG, HEIC, AVIF or WebP file" ], artist.errors.full_messages
    end
  end

  test "rejects a file that isn't an image" do
    artist = Artist.new(name: "Jane Smith", photo: { io: file_fixture("not_an_image.jpg").open, filename: "not_an_image.jpg" })

    assert_not artist.valid?
    assert_equal [ "This photo couldn’t be read. Choose a JPEG, HEIC, AVIF or WebP file." ], artist.errors.full_messages
  end

  test "rejects a photo with too many pixels, before decoding it" do
    artist = Artist.new(name: "Jane Smith", photo: { io: StringIO.new(Vips::Image.black(8000, 7000).jpegsave_buffer), filename: "huge.jpg" })

    assert_not artist.valid?
    assert_equal [ "the photo must be at most 50 megapixels" ], artist.errors.full_messages
  end

  test "rejects a photo whose data is cut off" do
    artist = Artist.new(name: "Jane Smith", photo: { io: file_fixture("truncated.jpg").open, filename: "truncated.jpg" })

    assert_not artist.valid?
    assert_equal [ "This photo couldn’t be read. Choose a JPEG, HEIC, AVIF or WebP file." ], artist.errors.full_messages
  end

  test "checks the minimum size of a sideways photo as it's displayed" do
    # Stored 440 × 400, with an EXIF orientation that displays it 400 × 440.
    artist = Artist.new(name: "Jane Smith", photo: { io: file_fixture("sideways.jpg").open, filename: "sideways.jpg" })

    assert artist.valid?, artist.errors.full_messages.to_sentence
  end

  test "rejects a photo narrower than the minimum width" do
    artist = Artist.new(name: "Jane Smith", photo: { io: StringIO.new(Vips::Image.black(399, 440).jpegsave_buffer), filename: "narrow.jpg" })

    assert_not artist.valid?
    assert_equal [ "the photo must be at least 400 pixels wide" ], artist.errors.full_messages
  end

  test "rejects a photo shorter than the minimum height" do
    artist = Artist.new(name: "Jane Smith", photo: { io: StringIO.new(Vips::Image.black(400, 439).jpegsave_buffer), filename: "short.jpg" })

    assert_not artist.valid?
    assert_equal [ "the photo must be at least 440 pixels tall" ], artist.errors.full_messages
  end

  test "rejects a photo too narrow and too short with both messages" do
    artist = Artist.new(name: "Jane Smith", photo: { io: file_fixture("tiny.jpg").open, filename: "tiny.jpg" })

    assert_not artist.valid?
    assert_equal [ "the photo must be at least 400 pixels wide", "the photo must be at least 440 pixels tall" ], artist.errors.full_messages
  end

  test "accepts a photo smaller than the minimum size when importing" do
    artist = Artist.new(name: "Jane Smith", photo: { io: file_fixture("tiny.jpg").open, filename: "tiny.jpg" })

    assert artist.valid?(:photo_import)
  end

  test "rejects a photo larger than the size limit" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "large.jpg")
      Vips::Image.gaussnoise(2600, 2600).cast(:uchar).bandjoin([ 0, 0 ]).copy(interpretation: :srgb).write_to_file(path, Q: 100)
      assert_operator File.size(path), :>, Artist::PHOTO_MAX_BYTES

      artist = Artist.new(name: "Jane Smith", photo: { io: File.open(path), filename: "large.jpg" })

      assert_not artist.valid?
      assert_equal [ "the photo must be smaller than 10 MB" ], artist.errors.full_messages
    end
  end

  test "stores a photo as an upright JPEG named after the slug, without metadata, whatever was uploaded" do
    artist = attach_photo(artists(:one), "sideways.jpg")
    image = Vips::Image.new_from_buffer(artist.photo.download, "")

    assert_equal [ "test-artist.jpg", "image/jpeg" ], [ artist.photo.filename.to_s, artist.photo.content_type ]
    assert_equal [ 400, 440 ], [ image.width, image.height ]
    assert_empty image.get_fields.grep(/exif|orientation/)

    attach_photo(artist, "photo.heic")
    assert_equal [ "test-artist.jpg", "image/jpeg" ], [ artist.photo.filename.to_s, artist.photo.content_type ]
    assert_equal "jpegload_buffer", Vips::Image.new_from_buffer(artist.photo.download, "").get("vips-loader")
  end

  test "stores a photo in another color space with its colors converted to sRGB" do
    # display_p3.jpg is photo.jpg converted to Display P3, with that profile.
    artist = attach_photo(artists(:one), "display_p3.jpg")
    stored = Vips::Image.new_from_buffer(artist.photo.download, "")
    original = Vips::Image.new_from_file(file_fixture("photo.jpg").to_s)

    assert_equal 0, stored.get_typeof("icc-profile-data")
    assert_in_delta original.avg, stored.avg, 1
  end

  test "doesn't save an unreadable photo when saving without validation" do
    artist = artists(:one)
    artist.photo = { io: file_fixture("not_an_image.jpg").open, filename: "not_an_image.jpg" }

    assert_not artist.save(validate: false)
    assert_not artists(:one).reload.photo.attached?
  end

  test "stores the clean JPEG once when saved again before the transaction commits" do
    artist = artists(:one)

    assert_difference("ActiveStorage::Blob.count", 1) do
      Artist.transaction do
        artist.update!(photo: { io: file_fixture("photo.heic").open, filename: "photo.heic" })
        artist.update!(name: "Jane Smith")
      end
    end
    assert_equal "test-artist.jpg", artist.reload.photo.filename.to_s
  end

  test "names a new artist's photo after their new slug" do
    artist = Artist.create!(name: "Jane Smith", photo: { io: file_fixture("photo.jpg").open, filename: "Jane Smith - by John Doe.jpg" })

    assert_equal "jane-smith.jpg", artist.photo.filename.to_s
  end

  test "doesn't recheck a photo that's already saved" do
    artist = attach_photo(artists(:one))

    assert artist.reload.valid?(:update)
  end

  test "makes each photo size, and a social size no larger than 1200 pixels" do
    artist = attach_photo(artists(:one))

    Artist::PHOTO_SIZES.merge(social: [ 400, 440 ]).each do |name, size|
      image = Vips::Image.new_from_buffer(artist.photo.variant(name).processed.download, "")

      assert_equal size, [ image.width, image.height ], name
    end
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

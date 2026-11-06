require "test_helper"

class ImportArtistPhotosTest < ActiveSupport::TestCase
  setup do
    @dir = Pathname(Dir.mktmpdir)
  end

  teardown do
    FileUtils.rm_rf(@dir)
  end

  test "attaches each artist's photo by slug, including ones smaller than the minimum" do
    add_file("photo.jpg", as: artists(:one).slug)
    jane = Artist.create!(name: "Jane Smith")
    add_file("tiny.jpg", as: jane.slug)

    result = ImportArtistPhotos.call(directory: @dir)

    assert_equal [ jane, artists(:one) ].sort_by(&:name), result.attached
    assert_equal "#{artists(:one).slug}.jpg", artists(:one).reload.photo.filename.to_s
    assert jane.reload.photo.attached?
  end

  test "reports artists without a file and files without an artist" do
    add_file("photo.jpg", as: "jane-smith")

    result = ImportArtistPhotos.call(directory: @dir)

    assert_equal [ artists(:one) ], result.missing
    assert_equal [ @dir.join("jane-smith.jpg") ], result.unmatched
    assert_empty result.attached
  end

  test "skips artists who already have a photo, so it can run again" do
    saved = attach_photo(artists(:one)).photo.blob
    add_file("photo.jpg", as: artists(:one).slug)

    result = ImportArtistPhotos.call(directory: @dir)

    assert_equal [ artists(:one) ], result.skipped
    assert_equal saved, artists(:one).reload.photo.blob
  end

  test "reports a file that can't be attached" do
    add_file("not_an_image.jpg", as: artists(:one).slug)

    result = ImportArtistPhotos.call(directory: @dir)

    assert_equal({ artists(:one) => "This photo couldn’t be read. Choose a JPEG, HEIC, AVIF or WebP file." }, result.failed)
    assert_not artists(:one).reload.photo.attached?
  end

  test "a dry run attaches nothing" do
    add_file("photo.jpg", as: artists(:one).slug)

    result = ImportArtistPhotos.call(dry_run: true, directory: @dir)

    assert_equal [ artists(:one) ], result.attached
    assert_not artists(:one).reload.photo.attached?
  end

  test "a dry run reports a file that couldn't be attached" do
    add_file("not_an_image.jpg", as: artists(:one).slug)

    result = ImportArtistPhotos.call(dry_run: true, directory: @dir)

    assert_equal [ artists(:one) ], result.failed.keys
    assert_empty result.attached
  end

  private

    def add_file(fixture, as:)
      FileUtils.cp(file_fixture(fixture), @dir.join("#{as}.jpg"))
    end
end

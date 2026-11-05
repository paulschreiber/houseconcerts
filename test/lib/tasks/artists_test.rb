require "test_helper"

class ArtistsRakeTest < ActiveSupport::TestCase
  setup do
    load_rake_tasks
    Rake::Task["artists:import_photos"].reenable
  end

  test "import_photos reports what it attached and what it couldn't match" do
    result = ImportArtistPhotos::Result.new(attached: [ artists(:one) ], skipped: [], missing: [ Artist.new(name: "Jane Smith") ],
                                            unmatched: [ Pathname("public/photos/headshots/john-doe.jpg") ], failed: {})

    out, = with_stubbed(ImportArtistPhotos, :call, ->(dry_run:) { dry_run ? nil : result }) do
      capture_io { Rake::Task["artists:import_photos"].invoke }
    end

    assert_includes out, "Attached 1 photos"
    assert_includes out, "No photo file for: Jane Smith"
    assert_includes out, "No artist for: john-doe.jpg"
  end

  test "import_photos with DRY_RUN says what it would attach" do
    ENV["DRY_RUN"] = "1"
    result = ImportArtistPhotos::Result.new(attached: [ artists(:one) ], skipped: [], missing: [], unmatched: [], failed: {})

    out, = with_stubbed(ImportArtistPhotos, :call, ->(dry_run:) { dry_run ? result : nil }) do
      capture_io { Rake::Task["artists:import_photos"].invoke }
    end

    assert_includes out, "Would attach 1 photos"
  ensure
    ENV.delete("DRY_RUN")
  end
end

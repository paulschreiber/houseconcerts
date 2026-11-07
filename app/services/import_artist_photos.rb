# Attaches each artist's photo from public/photos/headshots/<slug>.jpg, for
# artists without an uploaded photo. Run once by artists:import_photos.
class ImportArtistPhotos
  DIRECTORY = Rails.public_path.join("photos/headshots")

  # attached, skipped (already had a photo) and missing (no file) are
  # artists; unmatched are the files no artist's slug matches; failed maps
  # each artist whose photo couldn't be saved to the validation errors.
  Result = Data.define(:attached, :skipped, :missing, :unmatched, :failed)

  def self.call(dry_run: false, directory: DIRECTORY)
    new(dry_run:, directory:).call
  end

  def initialize(dry_run:, directory:)
    @dry_run = dry_run
    @directory = Pathname(directory)
  end

  # With dry_run, nothing is saved: attached lists the artists whose photos
  # would be, and failed the ones that wouldn't.
  def call
    files = directory.glob("*.jpg").index_by { |path| path.basename(".jpg").to_s }
    result = Result.new(attached: [], skipped: [], missing: [], unmatched: [], failed: {})

    Artist.with_attached_photo.order(:name).each do |artist|
      file = files.delete(artist.slug)
      if artist.photo.attached?
        result.skipped << artist
      elsif file.nil?
        result.missing << artist
      elsif attach(artist, file)
        result.attached << artist
      else
        result.failed[artist] = artist.errors.full_messages.to_sentence
      end
    end

    result.unmatched.concat(files.values.sort)
    result
  end

  private

    attr_reader :dry_run, :directory

    def attach(artist, file)
      file.open("rb") do |io|
        artist.photo = { io:, filename: file.basename.to_s }
        context = %i[update photo_import]
        dry_run ? artist.valid?(context) : artist.save(context:)
      end
    end
end

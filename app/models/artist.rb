class Artist < ApplicationRecord
  include NamedSlug

  # The photo's sizes, as [width, height]: twice the size they're shown at
  # (ArtistPhotosHelper), for high-resolution screens.
  PHOTO_SIZES = { card: [ 400, 440 ], thumb: [ 100, 100 ] }.freeze
  PHOTO_CONTENT_TYPES = %w[image/jpeg image/heic image/heif image/avif image/webp].freeze
  PHOTO_MAX_BYTES = 10.megabytes
  # The most pixels a photo can have, checked before it's decoded: enough for
  # a 48-megapixel phone camera.
  PHOTO_MAX_PIXELS = 50_000_000
  PHOTO_MIN_SIZE = PHOTO_SIZES[:card]
  PHOTO_JPEG_QUALITY = 85

  has_many :artist_shows, dependent: :delete_all
  has_many :shows, through: :artist_shows
  # Every revision, drafts included. joins(:show) keeps the ordering when
  # preloaded, which loads shows separately; eager_load ignores it.
  has_many :invite_messages, -> { joins(:show).reorder(shows: { start: :asc, id: :asc }, revision: :asc) }, through: :shows

  # The stored photo is a JPEG without metadata (store_new_photo_as_clean_jpeg),
  # so its sizes are too. They're made in the background once it's uploaded,
  # with crops centered on the most interesting part, usually the face. A
  # :social size is for og:image and JSON-LD.
  has_one_attached :photo do |attachable|
    options = { saver: { quality: PHOTO_JPEG_QUALITY }, preprocessed: true }
    PHOTO_SIZES.each do |name, (width, height)|
      attachable.variant name, resize_to_fill: [ width, height, { crop: :attention } ], **options
    end
    attachable.variant :social, resize_to_limit: [ 1200, 1200 ], **options
  end

  validates :name, presence: true
  validates :url, url: true, allow_blank: true
  validate :photo_must_be_usable, if: :new_photo?
  # Most photos imported from public/photos/headshots are smaller.
  validate :photo_must_be_big_enough, if: :new_photo?, except_on: :photo_import
  before_save :store_new_photo_as_clean_jpeg, if: :new_photo?
  after_save :name_photo_after_slug, if: -> { photo.attached? && photo.filename != photo_filename }

  # The photo limits, as values for the messages that describe them.
  def self.photo_limits
    { width: PHOTO_MIN_SIZE[0], height: PHOTO_MIN_SIZE[1], megapixels: PHOTO_MAX_PIXELS / 1_000_000,
      size: ActiveSupport::NumberHelper.number_to_human_size(PHOTO_MAX_BYTES) }
  end

  private

    # A photo assigned since the last save, other than the clean JPEG that
    # store_new_photo_as_clean_jpeg put in its place.
    def new_photo?
      change = attachment_changes["photo"]
      photo.attached? && change.present? && !change.equal?(@clean_photo_change)
    end

    # Checks a new photo's type (detected from its contents), file size and
    # pixel count, before decoding all of it. Decoding also catches a server
    # whose libvips can't read HEIC or AVIF.
    def photo_must_be_usable
      blob = photo.blob
      if PHOTO_CONTENT_TYPES.exclude?(blob.content_type)
        errors.add(:photo, :content_type)
      elsif blob.byte_size > PHOTO_MAX_BYTES
        errors.add(:photo, :too_large, **self.class.photo_limits)
      elsif new_photo_image && new_photo_image.width * new_photo_image.height > PHOTO_MAX_PIXELS
        errors.add(:photo, :too_many_pixels, **self.class.photo_limits)
      elsif new_photo_jpeg.nil? # also when the header couldn't be read
        errors.add(:photo, :unreadable)
      end
    end

    # Checks the new photo's size as displayed, after rotating it upright.
    def photo_must_be_big_enough
      return if errors.include?(:photo)

      width, height = PHOTO_MIN_SIZE
      errors.add(:photo, :too_narrow, **self.class.photo_limits) if new_photo_image.width < width
      errors.add(:photo, :too_short, **self.class.photo_limits) if new_photo_image.height < height
    end

    # Stores the new photo as a JPEG named after the artist's slug, rotated
    # upright and without metadata (such as where it was taken, the camera and
    # the time), in place of the file uploaded.
    # Then drops what was worked out from the upload, which the record would
    # otherwise hold in memory (the upload, its pixels and the JPEG). An
    # unreadable photo, saved without validation, isn't saved.
    def store_new_photo_as_clean_jpeg
      jpeg = new_photo_jpeg
      throw :abort if jpeg.nil?

      @new_photo_values = nil
      self.photo = { io: StringIO.new(jpeg), filename: photo_filename, content_type: "image/jpeg" }
      @clean_photo_change = attachment_changes["photo"]
    end

    # The stored photo's name, after the artist's slug.
    def photo_filename
      "#{slug}.jpg"
    end

    # Renames the stored photo after the slug, when a rename changed it (or
    # the photo was stored under another name).
    def name_photo_after_slug
      photo.blob.update!(filename: photo_filename)
    end

    # The new photo, rotated upright by its EXIF orientation, or nil when
    # libvips can't read its header. Only the header is read until its pixels
    # are needed (new_photo_jpeg).
    def new_photo_image
      new_photo_value(:image) { Vips::Image.new_from_buffer(new_photo_data, "", fail_on: :error).autorot }
    end

    # The new photo as a clean JPEG (see store_new_photo_as_clean_jpeg), or nil
    # when libvips can't decode all of it.
    def new_photo_jpeg
      new_photo_value(:jpeg) { new_photo_image && in_srgb(new_photo_image).jpegsave_buffer(Q: PHOTO_JPEG_QUALITY, strip: true) }
    end

    # The image's colors converted to sRGB, using its color profile if it has
    # one: the JPEG is saved without a profile, which browsers read as sRGB.
    # iPhone photos, for example, are in Display P3.
    def in_srgb(image)
      if image.get_typeof("icc-profile-data") != 0
        image = image.icc_transform("srgb", embedded: true, input_profile: image.interpretation == :cmyk ? "cmyk" : "srgb")
      end
      image.interpretation == :srgb ? image : image.colourspace(:srgb)
    end

    # A value worked out from the new photo, or nil when libvips can't read
    # it. Kept while that photo is checked and saved, so it's read and decoded
    # once; assigning another photo starts over.
    def new_photo_value(key)
      change = attachment_changes["photo"]
      @new_photo_values = { change: } unless @new_photo_values&.fetch(:change).equal?(change)
      @new_photo_values.fetch(key) do
        @new_photo_values[key] = begin
          yield
        rescue Vips::Error
          nil
        end
      end
    end

    # The new photo's bytes: from the upload or IO being attached (rewound
    # for Active Storage to read), or from a blob that's already stored.
    def new_photo_data
      attachable = attachment_changes["photo"].attachable
      io = attachable.is_a?(Hash) ? attachable[:io] : attachable
      return photo.blob.download unless io.respond_to?(:read)

      io.read.tap { io.rewind }
    end
end

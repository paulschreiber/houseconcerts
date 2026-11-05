class Artist < ApplicationRecord
  extend FriendlyId

  # The photo's sizes, as [width, height]: twice the size they're shown at
  # (ArtistPhotosHelper), for high-resolution screens. A :social size is for
  # og:image and JSON-LD.
  PHOTO_SIZES = { card: [ 400, 440 ], thumb: [ 100, 100 ] }.freeze
  PHOTO_CONTENT_TYPES = %w[image/jpeg image/heic image/heif image/avif image/webp].freeze
  PHOTO_MAX_BYTES = 10.megabytes
  # The most pixels a photo can have, checked before it's decoded: enough for
  # a 48-megapixel phone camera.
  PHOTO_MAX_PIXELS = 50_000_000
  # The smallest photo accepted, as [width, height]: big enough for :card.
  PHOTO_MIN_SIZE = [ 400, 440 ].freeze
  PHOTO_JPEG_QUALITY = 85

  friendly_id :name_slug_candidates, use: :slugged

  has_many :artist_shows, dependent: :delete_all
  has_many :shows, through: :artist_shows
  # Every revision, drafts included. joins(:show) keeps the ordering when
  # preloaded, which loads shows separately; eager_load ignores it.
  has_many :invite_messages, -> { joins(:show).reorder(shows: { start: :asc, id: :asc }, revision: :asc) }, through: :shows

  # The stored photo is a JPEG without metadata (store_new_photo_as_clean_jpeg),
  # so its sizes are too. They're made in the background once it's uploaded,
  # with crops centered on the most interesting part, usually the face.
  has_one_attached :photo do |attachable|
    PHOTO_SIZES.each do |name, (width, height)|
      attachable.variant name, resize_to_fill: [ width, height, { crop: :attention } ],
                               saver: { quality: PHOTO_JPEG_QUALITY }, preprocessed: true
    end
    attachable.variant :social, resize_to_limit: [ 1200, 1200 ], saver: { quality: PHOTO_JPEG_QUALITY }, preprocessed: true
  end

  validates :name, presence: true
  validates :url, url: true, allow_blank: true
  validate :photo_must_be_usable, if: :new_photo?
  # Most photos imported from public/photos/headshots are smaller.
  validate :photo_must_be_big_enough, if: :new_photo?, except_on: :photo_import
  before_save :store_new_photo_as_clean_jpeg, if: :new_photo?

  private

    def new_photo?
      photo.attached? && attachment_changes["photo"].present?
    end

    # Checks a new photo's type (detected from its contents), file size and
    # pixel count, before decoding all of it. Decoding also catches a server
    # whose libvips can't read HEIC or AVIF.
    def photo_must_be_usable
      blob = photo.blob
      if PHOTO_CONTENT_TYPES.exclude?(blob.content_type)
        errors.add(:photo, :content_type)
      elsif blob.byte_size > PHOTO_MAX_BYTES
        errors.add(:photo, :too_large, size: ActiveSupport::NumberHelper.number_to_human_size(PHOTO_MAX_BYTES))
      elsif new_photo_image && new_photo_image.width * new_photo_image.height > PHOTO_MAX_PIXELS
        errors.add(:photo, :too_many_pixels, megapixels: PHOTO_MAX_PIXELS / 1_000_000)
      elsif new_photo_jpeg.nil? # also when the header couldn't be read
        errors.add(:photo, :unreadable)
      end
    end

    # Checks the new photo's size as displayed, after rotating it upright.
    def photo_must_be_big_enough
      return if errors.include?(:photo)

      width, height = PHOTO_MIN_SIZE
      errors.add(:photo, :too_small, width:, height:) if new_photo_image.width < width || new_photo_image.height < height
    end

    # Stores the new photo as a JPEG, rotated upright and without metadata
    # (such as where it was taken, the camera and the time), in place of the
    # file uploaded.
    def store_new_photo_as_clean_jpeg
      self.photo = { io: StringIO.new(new_photo_jpeg), filename: "#{photo.filename.base}.jpg", content_type: "image/jpeg" }
    end

    # The new photo, rotated upright by its EXIF orientation, or nil when
    # libvips can't read its header. Only the header is read until its pixels
    # are needed (new_photo_jpeg).
    def new_photo_image
      new_photo_values.fetch(:image) do |key|
        new_photo_values[key] = Vips::Image.new_from_buffer(new_photo_data, "", fail_on: :error).autorot
      rescue Vips::Error
        new_photo_values[key] = nil
      end
    end

    # The new photo as a clean JPEG (see store_new_photo_as_clean_jpeg), or nil
    # when libvips can't decode all of it.
    def new_photo_jpeg
      new_photo_values.fetch(:jpeg) do |key|
        new_photo_values[key] = new_photo_image&.jpegsave_buffer(Q: PHOTO_JPEG_QUALITY, strip: true)
      rescue Vips::Error
        new_photo_values[key] = nil
      end
    end

    # Values worked out from the new photo, kept while that photo is checked
    # and saved, so it's read and decoded once.
    def new_photo_values
      change = attachment_changes["photo"]
      @new_photo_values = { change: } unless @new_photo_values&.fetch(:change).equal?(change)
      @new_photo_values
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

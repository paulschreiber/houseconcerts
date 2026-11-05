# Artist photos, shown at half the size of their images in
# Artist::PHOTO_SIZES so they're sharp on high-resolution screens. An artist
# without an uploaded photo falls back to their file in
# public/photos/headshots, if there is one, until those files are imported
# (artists:import_photos).
module ArtistPhotosHelper
  PHOTO_DISPLAY_SIZES = Artist::PHOTO_SIZES.transform_values { |size| size.map { |pixels| pixels / 2 } }.freeze
  LEGACY_PHOTO_PATHS = { card: "photos/headshots/%s.jpg", thumb: "photos/headshots/thumb/%s.jpg" }.freeze

  # Whether the artist has a photo to show at this size.
  def artist_photo?(artist, size)
    artist.photo.attached? || legacy_artist_photo_path(artist, size).present?
  end

  # An img tag for the artist's photo, or nil when the artist has no photo.
  def artist_photo_tag(artist, size, **options)
    width, height = PHOTO_DISPLAY_SIZES.fetch(size)
    options = { width:, height:, alt: artist.name, **options }

    if artist.photo.attached?
      image_tag(artist.photo.variant(size), **options)
    elsif (path = legacy_artist_photo_path(artist, size))
      image_tag("/#{path}", **options)
    end
  end

  # The absolute URL of the artist's photo for sharing (og:image and
  # JSON-LD), or nil when the artist has no photo.
  def artist_photo_url(artist)
    if artist.photo.attached?
      polymorphic_url(artist.photo.variant(:social))
    elsif (path = legacy_artist_photo_path(artist, :card))
      "#{root_url}#{path}"
    end
  end

  private

    def legacy_artist_photo_path(artist, size)
      path = format(LEGACY_PHOTO_PATHS.fetch(size), artist.slug)
      path if Rails.public_path.join(path).file?
    end
end

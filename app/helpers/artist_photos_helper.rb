# Artist photos, shown at half the size of their images in
# Artist::PHOTO_SIZES so they're sharp on high-resolution screens.
module ArtistPhotosHelper
  PHOTO_DISPLAY_SIZES = Artist::PHOTO_SIZES.transform_values { |size| size.map { |pixels| pixels / 2 } }.freeze

  # Whether the artist has a photo to show.
  def artist_photo?(artist)
    artist.photo.attached?
  end

  # An img tag for the artist's photo, or nil when the artist has no photo.
  def artist_photo_tag(artist, size, **)
    return unless artist.photo.attached?

    width, height = PHOTO_DISPLAY_SIZES.fetch(size)
    image_tag(artist.photo.variant(size), width:, height:, alt: artist.name, **)
  end

  # The absolute URL of the artist's photo for sharing (og:image and
  # JSON-LD), or nil when the artist has no photo.
  def artist_photo_url(artist)
    polymorphic_url(artist.photo.variant(:social)) if artist.photo.attached?
  end
end

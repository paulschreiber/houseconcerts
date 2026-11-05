# An artist's photo, shown at its card and thumb sizes: only photo sizes are
# served (see config/routes.rb). The file picker offers the formats Artist
# accepts. Under the photo, Madmin's Remove link deletes it
# (ActiveStorage::AttachmentResource).
class ArtistPhotoField < Madmin::Fields::Attachment
  include CustomPartials

  custom_partials :index, :show, :form
end

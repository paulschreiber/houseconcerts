# An artist's photo, shown at its card size: only photo sizes are served
# (see config/routes.rb). The file picker offers the formats Artist
# accepts. On the edit form, a Remove link under the photo deletes it
# (ActiveStorage::AttachmentResource).
class ArtistPhotoField < Madmin::Fields::Attachment
  include CustomPartials

  custom_partials :show, :form

  # The artist's saved photo. After an upload fails validation, the record
  # holds the rejected one, which isn't stored.
  def saved_photo(record)
    photo = value(record)
    return photo if !photo.attached? || photo.attachment.persisted?

    record.class.find_by(id: record.id)&.photo if record.persisted?
  end
end

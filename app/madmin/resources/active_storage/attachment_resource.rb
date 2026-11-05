# Lets admins remove an artist's photo: with this resource and its destroy
# route, Madmin's attachment fields show a Remove link (see ArtistPhotoField).
module ActiveStorage
  class AttachmentResource < Madmin::Resource
    menu false
  end
end

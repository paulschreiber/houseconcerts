module Madmin
  class ArtistsController < Madmin::ResourceController
    private

      # The index shows each artist's photo.
      def scoped_resources
        super.with_attached_photo
      end
  end
end

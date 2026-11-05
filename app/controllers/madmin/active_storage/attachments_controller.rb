module Madmin
  module ActiveStorage
    # Removes an attachment, such as an artist's photo, then returns to the
    # page of the record it belonged to. Its file is deleted in the background.
    class AttachmentsController < Madmin::ResourceController
      def destroy
        @record.destroy!
        owner = @record.record
        redirect_to Madmin.resource_for(owner).show_path(owner), status: :see_other
      end
    end
  end
end

module Madmin
  module ActiveStorage
    # Removes an attachment, such as an artist's photo, then returns to the
    # page of the record it belonged to. Its file is deleted in the background.
    class AttachmentsController < Madmin::ResourceController
      def destroy
        owner = @record.record
        owner_path = Madmin.resource_for(owner).show_path(owner)
        if @record.destroy
          redirect_to owner_path, status: :see_other
        else
          destroy_failed destroy_errors
        end
      end
    end
  end
end

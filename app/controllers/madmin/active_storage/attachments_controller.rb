module Madmin
  module ActiveStorage
    # Removes an attachment, such as an artist's photo. Turbo requests get a
    # stream that removes it from the edit form, where the Remove link is, so
    # the form keeps any unsaved changes; others return to that form. Its file
    # is deleted in the background.
    class AttachmentsController < Madmin::ResourceController
      def destroy
        owner = @record.record
        if @record.destroy
          respond_to do |format|
            format.turbo_stream { render turbo_stream: turbo_stream.remove(helpers.dom_id(owner, @record.name)) }
            format.html { redirect_to Madmin.resource_for(owner).edit_path(owner), status: :see_other }
          end
        else
          destroy_failed destroy_errors
        end
      end
    end
  end
end

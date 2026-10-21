module Madmin
  # The list of every show's invite revisions (see InviteResource).
  class InvitesController < Madmin::ResourceController
    private

      def scoped_resources
        super.includes(:show)
      end

      # Which of the page's revisions are sent, in one query instead of one
      # per row (see InviteResource.locked?).
      def paginate_collection(collection)
        page, records = super
        Current.locked_invite_message_ids = InviteMessage.locked_ids(records.map(&:id))
        [ page, records ]
      end
  end
end

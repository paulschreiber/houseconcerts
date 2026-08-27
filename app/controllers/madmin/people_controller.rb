module Madmin
  class PeopleController < Madmin::ResourceController
    before_action { Current.admin_scope = params[:scope] }

    def invite
      show = Show.next
      if @record.can_invite? && show
        InvitePerson.call(@record, show)
        redirect_back_or_to resource.index_path, notice: "Invited #{@record.full_name} to #{show.name}."
      else
        redirect_back_or_to resource.index_path, alert: "#{@record.full_name} can’t be invited."
      end
    end

    private

      # The "removed" scope (recent unsubscriptions) defaults to newest-first,
      # unless the admin explicitly clicks a different column to sort by.
      def scoped_resources
        resources = super
        return resources.reorder(removed_at: :desc) if params[:scope] == "removed" && params[:sort].blank?

        resources
      end
  end
end

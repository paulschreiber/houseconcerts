module Madmin
  class PeopleController < Madmin::ResourceController
    before_action { Current.admin_scope = params[:scope] }

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

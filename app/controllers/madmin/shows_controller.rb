module Madmin
  class ShowsController < Madmin::ResourceController
    private

      # Sort upcoming shows soonest-first; every other scope (including no
      # scope at all) most-recent-first, unless the admin has explicitly
      # clicked a column to sort by.
      def scoped_resources
        resources = super
        return resources if params[:sort].present?

        case params[:scope]
        when "upcoming"
          resources.reorder(start: :asc)
        else
          resources.reorder(start: :desc)
        end
      end
  end
end

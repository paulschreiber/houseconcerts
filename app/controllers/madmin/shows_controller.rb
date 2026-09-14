module Madmin
  class ShowsController < Madmin::ResourceController
    private

      # Every scope but "upcoming" is already sorted most-recent-first by
      # ShowResource.default_sort_column/default_sort_direction. Upcoming
      # shows need the opposite direction (soonest first), unless the admin
      # has explicitly clicked a column to sort by.
      def scoped_resources
        resources = super
        return resources.reorder(start: :asc) if params[:scope] == "upcoming" && params[:sort].blank?

        resources
      end
  end
end

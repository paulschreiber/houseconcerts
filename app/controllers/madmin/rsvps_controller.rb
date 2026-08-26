module Madmin
  class RsvpsController < Madmin::ResourceController
    before_action { Current.admin_scope = params[:scope] }

    helper_method :attendee_totals

    private

      # Memoized so the totals reflect the exact (search/sort-filtered) set
      # of records the index page paginates, not just the current page.
      def scoped_resources
        @scoped_resources ||= super
      end

      def attendee_totals
        return unless %w[next_show_attendees previous_show_attendees].include?(params[:scope])

        { count: @scoped_resources.count, seats_reserved: @scoped_resources.sum(:seats_reserved) }
      end
  end
end

module Madmin
  class RsvpsController < Madmin::ResourceController
    before_action { Current.admin_scope = params[:scope] }

    helper_method :attendee_totals

    def confirm
      if @record.can_confirm?
        ConfirmRSVP.call(@record)
        redirect_back_or_to resource.index_path, notice: "Confirmed #{@record.full_name}'s RSVP for #{@record.show&.name}."
      else
        redirect_back_or_to resource.index_path, alert: "#{@record.full_name}'s RSVP can't be confirmed."
      end
    end

    def waitlist
      if @record.can_waitlist?
        WaitlistRSVP.call(@record)
        redirect_back_or_to resource.index_path, notice: "Waitlisted #{@record.full_name}'s RSVP for #{@record.show&.name}."
      else
        redirect_back_or_to resource.index_path, alert: "#{@record.full_name}'s RSVP can't be waitlisted."
      end
    end

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

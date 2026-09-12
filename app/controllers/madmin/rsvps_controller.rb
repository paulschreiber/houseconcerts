module Madmin
  class RsvpsController < Madmin::ResourceController
    before_action { Current.admin_scope = params[:scope] }
    before_action :next_show, if: -> { Current.admin_scope == "next_show_attendees" }
    skip_before_action :set_record, only: :print

    helper_method :attendee_totals

    def print
      @show = Show.next
      @rsvps = RSVP.next_show_attendees(@show).order(:last_name, :first_name).to_a
      @rsvp_count = @rsvps.size
      @total_seats = @rsvps.sum(&:seats_reserved)

      emails = @rsvps.map(&:email)
      @subscribed_emails = Person.where(email: emails).pluck(:email).to_set
      @attended_emails = RSVP.attended(emails).reorder(nil).pluck(:email).to_set
    end

    def confirm
      if @record.can_confirm?
        ConfirmRSVP.call(@record)
        redirect_back_or_to resource.index_path, notice: "Confirmed #{@record.full_name}’s RSVP for #{@record.show&.name}."
      else
        redirect_back_or_to resource.index_path, alert: "#{@record.full_name}’s RSVP can’t be confirmed."
      end
    end

    def waitlist
      if @record.can_waitlist?
        WaitlistRSVP.call(@record)
        redirect_back_or_to resource.index_path, notice: "Waitlisted #{@record.full_name}’s RSVP for #{@record.show&.name}."
      else
        redirect_back_or_to resource.index_path, alert: "#{@record.full_name}’s RSVP can’t be waitlisted."
      end
    end

    def cancel
      if @record.can_cancel? && @record.cancel!
        redirect_back_or_to resource.index_path, notice: "Cancelled #{@record.full_name}’s RSVP for #{@record.show&.name}."
      else
        redirect_back_or_to resource.index_path, alert: "#{@record.full_name}’s RSVP can’t be cancelled."
      end
    end

    private

      # Memoized so the totals reflect the exact (search/sort-filtered) set
      # of records the index page paginates, not just the current page.
      # Preloads :show since every row renders the show name/date.
      def scoped_resources
        @scoped_resources ||= super.includes(:show)
      end

      def attendee_totals
        return unless %w[next_show_attendees previous_show_attendees].include?(params[:scope])

        { count: @scoped_resources.count, seats_reserved: @scoped_resources.sum(:seats_reserved) }
      end

      # Avoid re-running the "find the next show" query once per row.
      def next_show
        @next_show ||= Show.next
      end
  end
end

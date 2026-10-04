module Madmin
  class RsvpsController < Madmin::ResourceController
    include MemoizesNextShow
    include SortsByFullName

    before_action { Current.admin_scope = params[:scope] }
    before_action :next_show, if: -> { Current.admin_scope == "next_show_attendees" }

    ATTENDEE_SCOPES = %w[next_show_attendees previous_show_attendees].freeze

    helper_method :attendee_totals

    def confirm
      if @record.can_confirm? && ConfirmRSVP.call(@record)
        redirect_back_or_to resource.index_path, notice: "Confirmed #{@record.full_name}’s RSVP for #{@record.show&.name}."
      else
        redirect_back_or_to resource.index_path, alert: "#{@record.full_name}’s RSVP can’t be confirmed."
      end
    end

    def waitlist
      if @record.can_waitlist? && WaitlistRSVP.call(@record)
        redirect_back_or_to resource.index_path, notice: "Waitlisted #{@record.full_name}’s RSVP for #{@record.show&.name}."
      else
        redirect_back_or_to resource.index_path, alert: "#{@record.full_name}’s RSVP can’t be waitlisted."
      end
    end

    def cancel
      if @record.can_cancel?(next_show) && @record.cancel!
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
        return unless ATTENDEE_SCOPES.include?(params[:scope])

        { count: @scoped_resources.count, seats_reserved: @scoped_resources.sum(:seats_reserved) }
      end

      # Preload attended_before? for the whole page in one query instead of
      # one per row, but only when the Attended Before column is actually
      # shown for this scope.
      def paginate_collection(collection)
        pagy, records = super
        Current.attended_rsvp_ids_by_email = RSVP.attended_before_map(records.map(&:email)) unless resource.attributes[:attended_before].field.hidden_on_index?
        [ pagy, records ]
      end
  end
end

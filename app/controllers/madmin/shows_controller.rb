module Madmin
  class ShowsController < Madmin::ResourceController
    before_action :load_attendees, only: %i[attendance update_attendance print_attendance]

    # Records how many seats each of the show's attendees used.
    def attendance; end

    def update_attendance
      seats_used = params[:seats_used]
      seats_used = {} unless seats_used.is_a?(ActionController::Parameters)
      @rsvps.each do |rsvp|
        value = seats_used[rsvp.id.to_s]
        next if value.nil?

        rsvp.seats_used = value
        rsvp.validate
        # The model allows a blank seats_used (not recorded yet), but this
        # page is for recording it.
        rsvp.errors.add(:seats_used, t("madmin.shows.attendance.seats_used_blank")) if value.blank?
      end

      if @rsvps.all? { |rsvp| rsvp.errors.empty? }
        RSVP.transaction { @rsvps.each(&:save!) }
        redirect_to main_app.attendance_madmin_show_path(@show), notice: "Saved attendance for #{@show.name}."
      else
        flash.now[:alert] = t("madmin.shows.attendance.not_saved")
        render :attendance, status: :unprocessable_content
      end
    end

    # A printable list of the show's attendees, for the door.
    def print_attendance
      emails = @rsvps.map(&:email)
      @subscribed_emails = Person.where(email: emails).pluck(:email).to_set
      @attended_emails = RSVP.attended(emails).where(shows: { start: ...@show.start }).reorder(nil).pluck(:email).to_set
    end

    private

      def load_attendees
        @show = @record
        @rsvps = RSVP.attendees(@show).order(:last_name, :first_name).to_a
      end

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

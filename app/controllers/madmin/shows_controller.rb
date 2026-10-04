module Madmin
  class ShowsController < Madmin::ResourceController
    before_action do
      Current.admin_scope = params[:scope]
      Current.admin_action = action_name
    end
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

    # Adds the people who RSVPd yes to this show but aren't on the mailing
    # list. Anyone who unsubscribed (or is bouncing or moved) isn't re-added.
    def add_nonsubscribers
      result = AddNonsubscribers.call(@record)
      messages = []
      messages << "Added #{people_sentence(result.added)} to the mailing list." if result.added.any?
      messages << "Didn’t re-add #{people_sentence(result.skipped)}, who unsubscribed, bounced or moved." if result.skipped.any?
      messages << "Everyone who RSVPd yes is already on the mailing list." if messages.empty? && result.failed.empty?
      if result.failed.any?
        failures = result.failed.map { |rsvp, errors| "#{rsvp.full_name} (#{errors})" }.to_sentence
        flash[:alert] = "Couldn’t add #{failures}."
      end
      flash[:notice] = messages.join(" ") if messages.any?
      redirect_to main_app.madmin_show_path(@record)
    end

    # Fills in missing phone numbers on the mailing list from this show's RSVPs.
    def add_phone_numbers
      people = AddPhoneNumbers.call(@record)
      notice = people.any? ? "Added phone numbers for #{people_sentence(people)}." : "No phone numbers to add."
      redirect_to main_app.madmin_show_path(@record), notice:
    end

    # A printable list of the show's attendees, for the door.
    def print_attendance
      emails = @rsvps.map(&:email)
      @subscribed_emails = Person.where(email: emails).pluck(:email).to_set
      @attended_emails = RSVP.attended(emails).where(shows: { start: ...@show.start }).reorder(nil).pluck(:email).to_set
    end

    private

      def people_sentence(records)
        records.map(&:full_name).to_sentence
      end

      def load_attendees
        @show = @record
        @rsvps = RSVP.attendees(@show).order(:last_name, :first_name).to_a
      end
  end
end

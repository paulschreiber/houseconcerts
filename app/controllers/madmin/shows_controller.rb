module Madmin
  class ShowsController < Madmin::ResourceController
    before_action :load_attendees, only: %i[attendance update_attendance print_attendance]
    before_action :load_batch_run, only: %i[retry_failed_batch_run cancel_batch_run]

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
      redirect_back_or_to main_app.madmin_show_path(@record)
    end

    # Fills in missing phone numbers on the mailing list from this show's RSVPs.
    def add_phone_numbers
      people = AddPhoneNumbers.call(@record)
      notice = people.any? ? "Added phone numbers for #{people_sentence(people)}." : "No phone numbers to add."
      redirect_back_or_to main_app.madmin_show_path(@record), notice:
    end

    # A printable list of the show's attendees, for the door.
    def print_attendance
      emails = @rsvps.map(&:email)
      @subscribed_emails = Person.where(email: emails).pluck(:email).to_set
      @attended_emails = RSVP.attended(emails).where(shows: { start: ...@show.start }).reorder(nil).pluck(:email).to_set
    end

    # Starts a batch of one kind (see BatchRun::KINDS) for the next show.
    def start_batch_run
      kind = params[:kind].to_s
      return back_to_show(alert: "Unknown kind of batch.") unless BatchRun::KINDS.key?(kind)

      description = BatchRun.kind_description(kind)
      return back_to_show(alert: "Only the next show can have #{description} sent.") unless @record.next_show?

      StartBatchRun.call(show: @record, kind: kind)
      back_to_show(notice: "Started sending #{description} for #{@record.name}.")
    rescue StartBatchRun::AlreadyInProgress
      back_to_show(alert: "Already sending #{description} for #{@record.name} -- hang tight.")
    rescue StartBatchRun::NotReady, StartBatchRun::EnqueueFailed => e
      back_to_show(alert: e.message)
    end

    def retry_failed_batch_run
      return back_to_show(alert: "There are no failed #{@kind_label} sends to retry.") unless @batch_run

      retry_count = @batch_run.retry_failed!
      back_to_show(notice: "Retrying #{retry_count} failed #{@kind_label} for #{@record.name}.")
    rescue BatchRun::Refused => e
      back_to_show(alert: e.message)
    end

    def cancel_batch_run
      return back_to_show(alert: "There is no in-progress #{@kind_label} batch to cancel.") unless @batch_run

      @batch_run.cancel!
      back_to_show(notice: "Cancelled the #{@kind_label} batch for #{@record.name}.")
    rescue BatchRun::Refused => e
      back_to_show(alert: e.message)
    end

    private

      def people_sentence(records)
        records.map(&:full_name).to_sentence
      end

      def load_attendees
        @show = @record
        @rsvps = @show.attendees.order(:last_name, :first_name).to_a
      end

      # The batch run for retry and cancel. Keyed on the specific run, not "the
      # latest run of this kind": once a newer run of the same kind exists,
      # that would point at the wrong one and strand this run's failures.
      def load_batch_run
        @batch_run = @record.batch_runs.find_by(id: params.require(:batch_run_id))
        @kind_label = @batch_run ? @batch_run.lowercase_label : "batch"
      end

      def back_to_show(**flash)
        redirect_back_or_to resource.show_path(@record), **flash
      end
  end
end

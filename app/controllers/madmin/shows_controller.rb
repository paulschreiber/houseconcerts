module Madmin
  class ShowsController < Madmin::ResourceController
    before_action do
      Current.admin_scope = params[:scope]
      Current.admin_action = action_name
    end
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
      # The items themselves, not a cached counter, so a retry whose enqueue
      # failed partway can be retried again.
      failed_items = @batch_run&.batch_run_items&.failed

      if @batch_run.nil? || failed_items.none?
        back_to_show(alert: "There are no failed #{@kind_label} sends to retry.")
        return
      end

      # Sends for a show that's happened are useless; its failures stay visible
      # but can't be retried (BatchRunItemJob rechecks this too).
      if @record.occurred?
        back_to_show(alert: "#{@record.name} has already happened, so its failed #{@kind_label} sends can't be retried.")
        return
      end

      retry_count = failed_items.count

      # Reopened only if its status hasn't changed since it was read, so a
      # concurrent cancel isn't overwritten back to "running".
      begin
        reopened = BatchRun.where(id: @batch_run.id, status: @batch_run.status)
                           .update_all(status: BatchRun.statuses[:running], completed_at: nil) == 1 # rubocop:disable Rails/SkipsModelValidations
      rescue ActiveRecord::RecordNotUnique
        # active_kind_lock allows one unfinished run per show and kind.
        back_to_show(alert: "Can't retry right now -- a newer #{@kind_label} batch is already in progress for #{@record.name}. Try again once it finishes.")
        return
      end

      unless reopened
        back_to_show(alert: "Can't retry right now -- this #{@kind_label} batch's status just changed (it may have been cancelled). Please check and try again.")
        return
      end

      # Left "failed", so if the enqueue below fails they can still be offered
      # for retry. counted_at is cleared so they aren't counted until they
      # resolve again, and fan_out_enqueued_at so the fan-out picks them up.
      failed_items.update_all(counted_at: nil, fan_out_enqueued_at: nil) # rubocop:disable Rails/SkipsModelValidations

      # The fan-out job enqueues them, so a crash partway through enqueuing
      # doesn't strand the rest.
      begin
        BatchRunFanOutJob.perform_later(@batch_run.id)
      rescue ActiveRecord::AdapterError, SolidQueue::Job::EnqueueError
        # Solid Queue raises during perform_later; clicking Retry again picks
        # up where this left off.
        back_to_show(alert: "Couldn't start retrying #{@kind_label} sends right now -- please try again in a moment.")
        return
      end

      back_to_show(notice: "Retrying #{retry_count} failed #{@kind_label} for #{@record.name}.")
    end

    # Stops a run that's stuck or unwanted. Nothing else can finish a
    # "running" run with no failures, and until it finishes, active_kind_lock
    # blocks starting another of its kind for the show.
    def cancel_batch_run
      if @batch_run.nil? || @batch_run.completed?
        back_to_show(alert: "There is no in-progress #{@kind_label} batch to cancel.")
        return
      end

      # Pending items become "cancelled", which isn't claimable, so a job
      # already enqueued for one sends nothing. Resolved items keep their
      # outcome.
      @batch_run.batch_run_items.pending.update_all(status: BatchRunItem.statuses[:cancelled]) # rubocop:disable Rails/SkipsModelValidations
      @batch_run.update!(status: :completed, completed_at: Time.current)
      # So other admins viewing the show see it too.
      @batch_run.broadcast_progress

      back_to_show(notice: "Cancelled the #{@kind_label} batch for #{@record.name}.")
    end

    private

      def people_sentence(records)
        records.map(&:full_name).to_sentence
      end

      def load_attendees
        @show = @record
        @rsvps = RSVP.attendees(@show).order(:last_name, :first_name).to_a
      end

      # The batch run for retry and cancel. Keyed on the specific run, not "the
      # latest run of this kind": once a newer run of the same kind exists,
      # that would point at the wrong one and strand this run's failures.
      def load_batch_run
        @batch_run = @record.batch_runs.find_by(id: params.require(:batch_run_id))
        @kind_label = @batch_run ? BatchRun.kind_label(@batch_run.kind).downcase : "batch"
      end

      def back_to_show(**flash)
        redirect_back_or_to resource.show_path(@record), **flash
      end
  end
end

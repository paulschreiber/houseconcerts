module Madmin
  class ShowsController < Madmin::ResourceController
    before_action { Current.admin_scope = params[:scope] }

    def send_invites
      start_batch_run("invite", "invites")
    end

    def send_invites_unopened
      start_batch_run("invite_unopened", "invites to unopened recipients", require_invites_sent: true)
    end

    def send_reminders
      start_batch_run("remind", "reminders", require_invites_sent: true)
    end

    def retry_failed_batch_run
      kind = params.require(:kind)

      unless BatchRun.kinds.key?(kind)
        redirect_back_or_to resource.index_path, alert: "Unknown batch kind: #{kind}."
        return
      end

      batch_run = @record.batch_runs.where(kind: kind).order(created_at: :desc).first

      if batch_run.nil? || batch_run.failed_count.zero?
        redirect_back_or_to resource.index_path, alert: "There are no failed #{BatchRun.kind_label(kind).downcase} sends to retry."
        return
      end

      retry_count = batch_run.failed_count

      # Reopen the run so its progress bar shows again while the retries
      # are in flight -- BatchRunItemJob flips it back to completed once
      # every item (including these) has resolved again. failed_count is
      # reset to 0 (not left at its old value) because every failed item
      # is being retried here, and BatchRunItemJob#record_progress counts
      # each one fresh as it resolves -- without this reset,
      # processed_count would already equal total_count the instant the
      # run reopens, and the very first retried item to finish would
      # falsely flip the run back to "completed" while its siblings were
      # still in flight.
      batch_run.update!(status: :running, completed_at: nil, failed_count: 0)
      batch_run.batch_run_items.failed.find_each { |item| BatchRunItemJob.perform_later(item.id) }

      redirect_back_or_to resource.index_path, notice: "Retrying #{retry_count} failed #{BatchRun.kind_label(kind).downcase} for #{@record.name}."
    end

    private

      def start_batch_run(kind, description, require_invites_sent: false)
        if !@record.next_show?
          redirect_back_or_to resource.index_path, alert: "Only the next show can have #{description} sent."
        elsif require_invites_sent && !@record.invites_sent?
          redirect_back_or_to resource.index_path, alert: "Send the initial invites before sending #{description}."
        else
          StartBatchRun.call(show: @record, kind: kind)
          redirect_back_or_to resource.index_path, notice: "Started sending #{description} for #{@record.name}."
        end
      rescue StartBatchRun::AlreadyInProgress
        redirect_back_or_to resource.index_path, alert: "Already sending #{description} for #{@record.name} -- hang tight."
      end
  end
end

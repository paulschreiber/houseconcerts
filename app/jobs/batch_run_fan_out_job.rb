class BatchRunFanOutJob < ApplicationJob
  # Populates a BatchRun's items and enqueues their per-item jobs. Kept
  # separate from StartBatchRun (which just creates the BatchRun row) so
  # this slow part -- computing recipients and doing up to one insert +
  # one enqueue per recipient -- runs in the background instead of
  # blocking the admin's request.
  #
  # Resumable: if this job dies partway through (worker crash, deploy,
  # reboot) and Solid Queue redelivers it, recipients are recomputed and
  # re-attempted, but an item that already exists for a given recipient
  # (per the unique index on batch_run_items) is simply skipped rather
  # than duplicated. total_count is only set once, after every recipient
  # has been attempted, and per-item jobs are only enqueued after that --
  # so a job that's already running can't see a stale/incomplete count
  # and mark the run "completed" too early.
  def perform(batch_run_id)
    batch_run = BatchRun.find(batch_run_id)
    return unless batch_run.pending?

    recipients_for(batch_run).each do |recipient|
      batch_run.batch_run_items.create!(recipient: recipient, status: :pending)
    rescue ActiveRecord::RecordNotUnique
      next
    end

    total_count = batch_run.batch_run_items.count
    batch_run.update!(status: :running, total_count: total_count, started_at: Time.current)

    if total_count.zero?
      batch_run.update!(status: :completed, completed_at: Time.current)
    else
      batch_run.batch_run_items.pending.find_each { |item| BatchRunItemJob.perform_later(item.id) }
    end
  end

  private

    def recipients_for(batch_run)
      show = batch_run.show

      case batch_run.kind
      when "invite"
        invite_recipients(show)
      when "invite_unopened"
        invite_recipients(show).where("email NOT IN (SELECT email FROM opens WHERE tag LIKE ?)", "#{show.slug}:invite%")
      when "remind"
        show.attendees
      else
        raise ArgumentError, "unknown batch run kind: #{batch_run.kind}"
      end
    end

    def invite_recipients(show)
      Person.includes(:venue_groups)
            .where(venue_groups: { id: Settings.default_venue_group }, status: "active")
            .where("email NOT IN (SELECT email FROM rsvps WHERE show_id = ?)", show.id)
            .order(:last_name, :first_name)
    end
end

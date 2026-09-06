class StartBatchRun
  # Raised when a batch of this kind is genuinely running for this show.
  # A "pending" collision doesn't raise this -- see #resume_pending_run --
  # since a pending run's fan-out job may simply never have been
  # successfully enqueued, and self-healing that is safer than leaving an
  # admin with a permanently stuck batch and no way to recover it (the
  # unique index on batch_runs.active_kind_lock would otherwise block
  # every future send of this kind for this show).
  class AlreadyInProgress < StandardError; end

  # Raised when BatchRunFanOutJob.perform_later itself fails (Solid
  # Queue's Job.enqueue raises synchronously, at the point perform_later
  # is called, not later in a worker) -- e.g. a transient DB problem
  # writing the job row. The BatchRun itself is already created and
  # remains recoverable (a later call here will find it "pending" and
  # resume it, or an admin can just try again), but *this* request
  # should say so plainly instead of surfacing as a raw 500.
  class EnqueueFailed < StandardError; end

  def self.call(show:, kind:)
    new(show, kind).call
  end

  def initialize(show, kind)
    @show = show
    @kind = kind
  end

  # Only creates the BatchRun row and hands off the (potentially slow,
  # per-recipient) work to BatchRunFanOutJob, so this returns almost
  # immediately regardless of how many people are eligible.
  def call
    batch_run = BatchRun.create!(show: show, kind: kind, status: :pending)
    enqueue_fan_out(batch_run)
    batch_run
  rescue ActiveRecord::RecordNotUnique
    resume_pending_run || raise(AlreadyInProgress, "A #{kind} batch is already in progress for #{show.name}")
  end

  private

    attr_reader :show, :kind

    def enqueue_fan_out(batch_run)
      BatchRunFanOutJob.perform_later(batch_run.id)
    rescue ActiveRecord::AdapterError, SolidQueue::Job::EnqueueError
      raise EnqueueFailed, "Couldn't start the #{kind} batch for #{show.name} right now -- please try again in a moment."
    end

    # active_kind_lock only allows one non-completed run per show+kind, so
    # a RecordNotUnique collision means either a "pending" run (fan-out
    # never actually started -- possibly because its own enqueue above
    # failed on a previous attempt) or a "running" one (fan-out is
    # genuinely underway). Only the former is safe and useful to resume:
    # BatchRunFanOutJob is idempotent, so re-enqueuing it for a pending
    # run just re-attempts fan-out with no risk of duplicating anything.
    # A running run is left alone and reported as AlreadyInProgress.
    def resume_pending_run
      existing = show.batch_runs.find_by(kind: kind, status: :pending)
      return nil unless existing

      enqueue_fan_out(existing)
      existing
    end
end

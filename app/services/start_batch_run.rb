class StartBatchRun
  # A batch of this kind is already running for the show. (A pending one is
  # resumed instead; see resume_pending_run.)
  class AlreadyInProgress < StandardError; end

  # Enqueuing the fan-out job failed (Solid Queue raises during
  # perform_later, e.g. on a transient DB problem). The run stays pending, so
  # trying again resumes it.
  class EnqueueFailed < StandardError; end

  # Raised when this kind needs initial invites to have gone out first
  # (BatchRun::KINDS) and they haven't.
  class NotReady < StandardError; end

  def self.call(show:, kind:)
    new(show, kind).call
  end

  def initialize(show, kind)
    @show = show
    @kind = kind
  end

  # Creates the run and hands the per-recipient work to BatchRunFanOutJob,
  # so it returns at once however many people are eligible.
  def call
    raise NotReady, "Send the initial invites before sending #{BatchRun.kind_description(kind)}." if BatchRun.requires_invites_sent?(kind) && !show.invites_sent?

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

    # A collision with an unfinished run of the same kind: a pending one
    # (its fan-out never started) is safe to resume, since the fan-out job is
    # idempotent; a running one is left alone.
    def resume_pending_run
      existing = show.batch_runs.find_by(kind: kind, status: :pending)
      return nil unless existing

      enqueue_fan_out(existing)
      existing
    end
end

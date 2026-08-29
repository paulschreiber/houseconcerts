class StartBatchRun
  # Raised when a batch of this kind is already running/pending for this
  # show, per the unique index on batch_runs.active_kind_lock -- that index
  # (not this check) is what actually prevents two in-flight runs of the
  # same kind from ever coexisting, even under concurrent requests.
  class AlreadyInProgress < StandardError; end

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
    BatchRunFanOutJob.perform_later(batch_run.id)
    batch_run
  rescue ActiveRecord::RecordNotUnique
    raise AlreadyInProgress, "A #{kind} batch is already in progress for #{show.name}"
  end

  private

    attr_reader :show, :kind
end

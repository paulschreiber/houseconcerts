require "test_helper"

class StartBatchRunTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "creates a pending batch run and enqueues the fan-out job" do
    show = shows(:upcoming)

    batch_run = nil
    assert_enqueued_with(job: BatchRunFanOutJob) do
      batch_run = StartBatchRun.call(show: show, kind: "invite")
    end

    assert_equal "invite", batch_run.kind
    assert batch_run.pending?
    assert_equal 0, batch_run.total_count
  end

  test "starting invite again while the first run is genuinely running raises instead of double-sending" do
    show = shows(:upcoming)
    first_run = StartBatchRun.call(show: show, kind: "invite")
    first_run.update!(status: :running)

    assert_raises(StartBatchRun::AlreadyInProgress) do
      StartBatchRun.call(show: show, kind: "invite")
    end
    assert_equal 1, BatchRun.where(show: show, kind: "invite").count
  end

  test "starting invite again while the first run is still pending re-enqueues its fan-out job instead of raising" do
    show = shows(:upcoming)
    # Simulates the first attempt's own BatchRunFanOutJob.perform_later
    # having silently failed to enqueue: the run exists and is still
    # pending, but no job was ever queued for it.
    first_run = BatchRun.create!(show: show, kind: "invite", status: :pending)

    second_run = nil
    assert_enqueued_with(job: BatchRunFanOutJob, args: [ first_run.id ]) do
      assert_nothing_raised do
        second_run = StartBatchRun.call(show: show, kind: "invite")
      end
    end

    assert_equal first_run.id, second_run.id
    assert_equal 1, BatchRun.where(show: show, kind: "invite").count
  end

  test "starting a different kind while invite is in progress for the same show is unaffected" do
    show = shows(:upcoming)
    StartBatchRun.call(show: show, kind: "invite")

    assert_nothing_raised do
      StartBatchRun.call(show: show, kind: "remind")
    end
  end

  test "a second invite run can start once the first has completed" do
    show = shows(:upcoming)
    first_run = BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 0, completed_at: Time.current)

    second_run = nil
    assert_nothing_raised do
      second_run = StartBatchRun.call(show: show, kind: "invite")
    end

    assert_not_equal first_run.id, second_run.id
  end

  test "raises a friendly EnqueueFailed instead of a raw error when perform_later itself fails" do
    show = shows(:upcoming)

    original_perform_later = BatchRunFanOutJob.method(:perform_later)
    BatchRunFanOutJob.define_singleton_method(:perform_later) do |*_args|
      raise SolidQueue::Job::EnqueueError, "transient boom"
    end

    begin
      error = assert_raises(StartBatchRun::EnqueueFailed) do
        StartBatchRun.call(show: show, kind: "invite")
      end
      assert_match(/try again/, error.message)
    ensure
      BatchRunFanOutJob.define_singleton_method(:perform_later, original_perform_later)
    end

    # The BatchRun itself is still there, pending, and recoverable -- a
    # later call finds and resumes it instead of raising again.
    assert_equal 1, BatchRun.where(show: show, kind: "invite", status: "pending").count
  end

  test "resuming a pending run also raises a friendly EnqueueFailed if its own perform_later fails" do
    show = shows(:upcoming)
    BatchRun.create!(show: show, kind: "invite", status: :pending)

    original_perform_later = BatchRunFanOutJob.method(:perform_later)
    BatchRunFanOutJob.define_singleton_method(:perform_later) do |*_args|
      raise SolidQueue::Job::EnqueueError, "transient boom"
    end

    begin
      assert_raises(StartBatchRun::EnqueueFailed) do
        StartBatchRun.call(show: show, kind: "invite")
      end
    ensure
      BatchRunFanOutJob.define_singleton_method(:perform_later, original_perform_later)
    end

    assert_equal 1, BatchRun.where(show: show, kind: "invite").count
  end
end

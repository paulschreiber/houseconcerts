require "test_helper"

class StartBatchRunTest < ActiveSupport::TestCase
  include BatchTestHelpers
  include ActiveJob::TestHelper

  test "creates a pending batch run and enqueues the fan-out job" do
    batch_run = nil
    assert_enqueued_with(job: BatchRunFanOutJob) do
      batch_run = StartBatchRun.call(show: show, kind: "invite")
    end

    assert_equal "invite", batch_run.kind
    assert batch_run.pending?
    assert_equal 0, batch_run.total_count
  end

  test "starting invite again while the first run is genuinely running raises instead of double-sending" do
    first_run = StartBatchRun.call(show: show, kind: "invite")
    first_run.update!(status: :running)

    assert_raises(StartBatchRun::AlreadyInProgress) do
      StartBatchRun.call(show: show, kind: "invite")
    end
    assert_equal 1, BatchRun.where(show: show, kind: "invite").count
  end

  test "starting invite again while the first run is still pending re-enqueues its fan-out job instead of raising" do
    # Simulates the first attempt's own BatchRunFanOutJob.perform_later
    # having silently failed to enqueue: the run exists and is still
    # pending, but no job was ever queued for it.
    first_run = create_run(status: :pending, total_count: 0)

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
    create_run(status: "completed", sent_count: 1, completed_at: 1.day.ago)
    StartBatchRun.call(show: show, kind: "invite")

    assert_nothing_raised do
      StartBatchRun.call(show: show, kind: "remind")
    end
  end

  test "invites to unopened recipients and reminders need the initial invites to have gone out" do
    %w[invite_unopened remind].each do |kind|
      assert_raises(StartBatchRun::NotReady, kind) { StartBatchRun.call(show: shows(:upcoming), kind:) }
    end
    assert_equal 0, shows(:upcoming).batch_runs.count
  end

  test "a second invite run can start once the first has completed" do
    first_run = create_run(status: "completed", total_count: 0, completed_at: Time.current)

    second_run = nil
    assert_nothing_raised do
      second_run = StartBatchRun.call(show: show, kind: "invite")
    end

    assert_not_equal first_run.id, second_run.id
  end

  test "raises a friendly EnqueueFailed instead of a raw error when perform_later itself fails" do
    with_stubbed(BatchRunFanOutJob, :perform_later, ->(*_args) { raise SolidQueue::Job::EnqueueError, "transient boom" }) do
      error = assert_raises(StartBatchRun::EnqueueFailed) do
        StartBatchRun.call(show: show, kind: "invite")
      end
      assert_match(/try again/, error.message)
    end

    # The BatchRun itself is still there, pending, and recoverable -- a
    # later call finds and resumes it instead of raising again.
    assert_equal 1, BatchRun.where(show: show, kind: "invite", status: "pending").count
  end

  test "resuming a pending run also raises a friendly EnqueueFailed if its own perform_later fails" do
    create_run(status: :pending, total_count: 0)

    with_stubbed(BatchRunFanOutJob, :perform_later, ->(*_args) { raise SolidQueue::Job::EnqueueError, "transient boom" }) do
      assert_raises(StartBatchRun::EnqueueFailed) do
        StartBatchRun.call(show: show, kind: "invite")
      end
    end

    assert_equal 1, BatchRun.where(show: show, kind: "invite").count
  end
end

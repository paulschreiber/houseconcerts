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

  test "starting invite again while the first run is still in progress raises instead of double-sending" do
    show = shows(:upcoming)
    first_run = StartBatchRun.call(show: show, kind: "invite")
    assert first_run.pending?

    assert_raises(StartBatchRun::AlreadyInProgress) do
      StartBatchRun.call(show: show, kind: "invite")
    end
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
end

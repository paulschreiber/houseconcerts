require "test_helper"

class BatchRunTest < ActiveSupport::TestCase
  include BatchTestHelpers
  include ActiveJob::TestHelper

  test "processed_count sums sent and failed counts" do
    batch_run = BatchRun.new(sent_count: 2, failed_count: 1)

    assert_equal 3, batch_run.processed_count
  end

  test "belongs to a show and has many batch_run_items" do
    batch_run = create_run(status: "pending")
    item = batch_run.batch_run_items.create!(recipient: people(:one))

    assert_equal shows(:upcoming), batch_run.show
    assert_includes batch_run.batch_run_items, item
  end

  test "retry_failed! reopens the run, resets its failed items and enqueues the fan-out" do
    batch_run = create_run(status: "completed", completed_at: Time.current)
    item = batch_run.batch_run_items.create!(recipient: people(:one), status: :failed, counted_at: Time.current, fan_out_enqueued_at: Time.current)

    retry_count = nil
    assert_enqueued_with(job: BatchRunFanOutJob, args: [ batch_run.id ]) do
      retry_count = batch_run.retry_failed!
    end

    assert_equal 1, retry_count
    assert batch_run.reload.running?
    assert_nil batch_run.completed_at
    item.reload
    assert item.failed?
    assert_nil item.counted_at
    assert_nil item.fan_out_enqueued_at
  end

  test "retry_failed! refuses a run with no failed items" do
    batch_run = create_run

    error = assert_raises(BatchRun::Refused) { batch_run.retry_failed! }
    assert_equal "There are no failed invites sends to retry.", error.message
  end

  test "retry_failed! refuses a show that has already happened" do
    batch_run = create_run(show: shows(:past))
    batch_run.batch_run_items.create!(recipient: people(:one), status: :failed)

    error = assert_raises(BatchRun::Refused) { batch_run.retry_failed! }
    assert_match(/has already happened/, error.message)
  end

  test "retry_failed! refuses while a newer run of the same kind is unfinished" do
    batch_run = create_run(status: "completed", completed_at: Time.current)
    batch_run.batch_run_items.create!(recipient: people(:one), status: :failed)
    create_run

    error = assert_raises(BatchRun::Refused) { batch_run.retry_failed! }
    assert_match(/a newer invites batch is already in progress/, error.message)
    assert batch_run.reload.completed?
  end

  test "cancel! cancels pending items, keeps resolved ones and completes the run" do
    batch_run = create_run(total_count: 2)
    pending = batch_run.batch_run_items.create!(recipient: people(:one), status: :pending)
    sent = batch_run.batch_run_items.create!(recipient: rsvps(:one), status: :sent)

    batch_run.cancel!

    assert batch_run.reload.completed?
    assert_not_nil batch_run.completed_at
    assert pending.reload.cancelled?
    assert sent.reload.sent?
  end

  test "cancel! refuses a completed run" do
    batch_run = create_run(status: "completed", completed_at: Time.current)

    error = assert_raises(BatchRun::Refused) { batch_run.cancel! }
    assert_equal "There is no in-progress invites batch to cancel.", error.message
  end
end

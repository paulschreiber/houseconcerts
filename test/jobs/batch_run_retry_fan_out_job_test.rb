require "test_helper"

class BatchRunRetryFanOutJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "enqueues a job for every currently-failed item" do
    show = shows(:upcoming)
    person_a = Person.create!(first_name: "Retry", last_name: "Aardvark", email: "retry-fanout-a@example.com", status: "active")
    person_b = Person.create!(first_name: "Retry", last_name: "Baboon", email: "retry-fanout-b@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 2, failed_count: 0)
    batch_run.batch_run_items.create!(recipient: person_a, status: "failed", error_message: "boom")
    batch_run.batch_run_items.create!(recipient: person_b, status: "failed", error_message: "boom")

    assert_enqueued_jobs 2, only: BatchRunItemJob do
      BatchRunRetryFanOutJob.perform_now(batch_run.id)
    end
  end

  test "does not enqueue a job for items that are already sent" do
    show = shows(:upcoming)
    person = Person.create!(first_name: "Already", last_name: "Sent", email: "retry-fanout-sent@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1, failed_count: 0, sent_count: 1)
    batch_run.batch_run_items.create!(recipient: person, status: "sent", sent_at: Time.current)

    assert_no_enqueued_jobs only: BatchRunItemJob do
      BatchRunRetryFanOutJob.perform_now(batch_run.id)
    end
  end

  test "resuming after a crash mid-enqueue re-enqueues only the items still failed, not the ones already resolved" do
    show = shows(:upcoming)
    person_a = Person.create!(first_name: "Retry", last_name: "Resolved", email: "retry-fanout-resolved@example.com", status: "active")
    person_b = Person.create!(first_name: "Retry", last_name: "Stranded", email: "retry-fanout-stranded@example.com", status: "active")
    # Simulates the controller's reset already having happened (status
    # running, failed_count reset to 0) and a first retry attempt having
    # enqueued and resolved item_a's job before crashing -- item_b never
    # got a job enqueued for it in that attempt.
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 2, failed_count: 0, sent_count: 1)
    batch_run.batch_run_items.create!(recipient: person_a, status: "sent", sent_at: Time.current)
    item_b = batch_run.batch_run_items.create!(recipient: person_b, status: "failed", error_message: "boom")

    assert_enqueued_jobs 1, only: BatchRunItemJob do
      BatchRunRetryFanOutJob.perform_now(batch_run.id)
    end

    assert_enqueued_with(job: BatchRunItemJob, args: [ item_b.id ])
  end

  test "retries the whole job instead of leaving failures unenqueued if a per-item enqueue raises a transient adapter error" do
    show = shows(:upcoming)
    person = Person.create!(first_name: "Retry", last_name: "Transient", email: "retry-fanout-transient@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1, failed_count: 0)
    item = batch_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")

    original_perform_later = BatchRunItemJob.method(:perform_later)
    BatchRunItemJob.define_singleton_method(:perform_later) do |*_args|
      raise ActiveRecord::ConnectionTimeoutError, "transient enqueue failure"
    end

    begin
      assert_enqueued_with(job: BatchRunRetryFanOutJob, args: [ batch_run.id ]) do
        assert_nothing_raised do
          BatchRunRetryFanOutJob.perform_now(batch_run.id)
        end
      end
    ensure
      BatchRunItemJob.define_singleton_method(:perform_later, original_perform_later)
    end

    # Nothing about the underlying item changed -- it's still there for
    # the retried job to find and enqueue.
    assert item.reload.failed?
  end

  test "a genuine bug is not retried -- it raises immediately instead of retrying against a job that will never fix itself" do
    show = shows(:upcoming)
    person = Person.create!(first_name: "Retry", last_name: "Buggy", email: "retry-fanout-bug@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1, failed_count: 0)
    batch_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")

    original_perform_later = BatchRunItemJob.method(:perform_later)
    BatchRunItemJob.define_singleton_method(:perform_later) do |*_args|
      raise NoMethodError, "undefined method (simulated code bug, not a transient adapter error)"
    end

    begin
      assert_no_enqueued_jobs only: BatchRunRetryFanOutJob do
        assert_raises(NoMethodError) do
          BatchRunRetryFanOutJob.perform_now(batch_run.id)
        end
      end
    ensure
      BatchRunItemJob.define_singleton_method(:perform_later, original_perform_later)
    end
  end
end

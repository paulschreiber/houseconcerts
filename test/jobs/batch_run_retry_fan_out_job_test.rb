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
end

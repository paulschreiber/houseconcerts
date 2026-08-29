require "test_helper"

class BatchRunFanOutJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "invite creates an item per eligible person, sets total_count, and enqueues a job for each" do
    show = shows(:upcoming)
    alice = Person.create!(first_name: "Alice", last_name: "Aardvark", email: "alice@example.com", status: "active")
    Person.create!(first_name: "Bob", last_name: "Zebra", email: "bob@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "pending")

    assert_enqueued_jobs 2, only: BatchRunItemJob do
      BatchRunFanOutJob.perform_now(batch_run.id)
    end

    batch_run.reload
    assert batch_run.running?
    assert_equal 2, batch_run.total_count
    assert_equal alice, batch_run.batch_run_items.first.recipient
    assert_equal "Person", batch_run.batch_run_items.first.recipient_type
  end

  test "invite excludes people who already have an rsvp for the show" do
    show = shows(:upcoming)
    person = Person.create!(first_name: "Already", last_name: "Rsvpd", email: "already-rsvpd@example.com", status: "active")
    RSVP.create!(show: show, email: person.email, first_name: "Already", last_name: "Rsvpd", response: "yes", seats_reserved: 1)
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "pending")

    BatchRunFanOutJob.perform_now(batch_run.id)

    assert_equal 0, batch_run.reload.total_count
  end

  test "invite_unopened further excludes people who already opened an invite for the show" do
    show = shows(:upcoming)
    person = Person.create!(first_name: "Opened", last_name: "Invite", email: "opened@example.com", status: "active")
    Open.create!(tag: "#{show.slug}:invite-abc", email: person.email, open: true)
    batch_run = BatchRun.create!(show: show, kind: "invite_unopened", status: "pending")

    BatchRunFanOutJob.perform_now(batch_run.id)

    assert_equal 0, batch_run.reload.total_count
  end

  test "remind targets the show's confirmed yes attendees" do
    show = shows(:upcoming)
    batch_run = BatchRun.create!(show: show, kind: "remind", status: "pending")

    BatchRunFanOutJob.perform_now(batch_run.id)

    batch_run.reload
    assert_equal 1, batch_run.total_count
    assert_equal rsvps(:one), batch_run.batch_run_items.first.recipient
  end

  test "a batch run with no eligible recipients completes immediately instead of staying running forever" do
    show = shows(:upcoming)
    person = Person.create!(first_name: "Already", last_name: "Rsvpd", email: "no-recipients@example.com", status: "active")
    RSVP.create!(show: show, email: person.email, first_name: "Already", last_name: "Rsvpd", response: "yes", seats_reserved: 1)
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "pending")

    BatchRunFanOutJob.perform_now(batch_run.id)

    batch_run.reload
    assert batch_run.completed?
    assert_not_nil batch_run.completed_at
  end

  test "resuming after a partial fan-out re-enqueues the leftover item but doesn't duplicate its row" do
    show = shows(:upcoming)
    alice = Person.create!(first_name: "Alice", last_name: "Aardvark", email: "alice@example.com", status: "active")
    Person.create!(first_name: "Bob", last_name: "Zebra", email: "bob@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "pending")

    # Simulate a crash partway through a previous attempt: Alice's item
    # already exists (created in that attempt) but never got a job
    # enqueued for it, since -- in the real flow -- enqueuing only happens
    # in a second pass after every recipient has been attempted.
    batch_run.batch_run_items.create!(recipient: alice, status: :pending)

    # Both items end up with a job: Bob's because it's new, Alice's
    # because it was never actually enqueued the first time around. What
    # must NOT happen is a second BatchRunItem row for Alice.
    assert_enqueued_jobs 2, only: BatchRunItemJob do
      BatchRunFanOutJob.perform_now(batch_run.id)
    end

    batch_run.reload
    assert_equal 2, batch_run.total_count
    assert_equal 1, batch_run.batch_run_items.where(recipient: alice).count
  end

  test "is a no-op if the batch run is no longer pending" do
    show = shows(:upcoming)
    Person.create!(first_name: "Alice", last_name: "Aardvark", email: "alice@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 0, completed_at: Time.current)

    assert_no_enqueued_jobs only: BatchRunItemJob do
      BatchRunFanOutJob.perform_now(batch_run.id)
    end

    assert_equal 0, batch_run.reload.batch_run_items.count
  end
end

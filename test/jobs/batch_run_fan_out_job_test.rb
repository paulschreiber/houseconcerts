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

  test "is a no-op once the batch run has completed" do
    show = shows(:upcoming)
    Person.create!(first_name: "Alice", last_name: "Aardvark", email: "alice@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 0, completed_at: Time.current)

    assert_no_enqueued_jobs only: BatchRunItemJob do
      BatchRunFanOutJob.perform_now(batch_run.id)
    end

    assert_equal 0, batch_run.reload.batch_run_items.count
  end

  test "resuming after a crash between the running flip and the enqueue loop still enqueues the stranded items" do
    show = shows(:upcoming)
    alice = Person.create!(first_name: "Alice", last_name: "Aardvark", email: "alice-resume@example.com", status: "active")
    bob = Person.create!(first_name: "Bob", last_name: "Zebra", email: "bob-resume@example.com", status: "active")
    # Simulates a worker crash after status was already flipped to
    # "running" (and both items already created) but before either job
    # got enqueued: without resuming past the pending? guard, these two
    # items would stay pending forever and the run would never complete.
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 2)
    batch_run.batch_run_items.create!(recipient: alice, status: :pending)
    batch_run.batch_run_items.create!(recipient: bob, status: :pending)

    assert_enqueued_jobs 2, only: BatchRunItemJob do
      BatchRunFanOutJob.perform_now(batch_run.id)
    end

    assert batch_run.reload.running?
  end

  test "retries the whole job instead of leaving the run stuck if enqueuing a per-item job raises Solid Queue's EnqueueError" do
    show = shows(:upcoming)
    Person.create!(first_name: "Alice", last_name: "Aardvark", email: "alice-transient@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "pending")

    # This, not a raw ActiveRecord::AdapterError, is what a transient DB
    # problem during perform_later actually surfaces as: Solid Queue's
    # Job.enqueue rescues ActiveRecord::ActiveRecordError and re-raises
    # it wrapped in this class.
    call_count = 0
    original_perform_later = BatchRunItemJob.method(:perform_later)
    BatchRunItemJob.define_singleton_method(:perform_later) do |*args|
      call_count += 1
      raise SolidQueue::Job::EnqueueError, "transient enqueue failure" if call_count == 1

      original_perform_later.call(*args)
    end

    begin
      assert_enqueued_with(job: BatchRunFanOutJob, args: [ batch_run.id ]) do
        assert_nothing_raised do
          BatchRunFanOutJob.perform_now(batch_run.id)
        end
      end
    ensure
      BatchRunItemJob.define_singleton_method(:perform_later, original_perform_later)
    end

    # The run is left in a state the retried job can cleanly resume from,
    # not stranded: the item already exists and total_count is already
    # set, so the retry just needs to enqueue what's still pending.
    batch_run.reload
    assert batch_run.running?
    assert_equal 1, batch_run.total_count
    assert_equal 1, batch_run.batch_run_items.pending.count
  end

  test "retries the whole job if its own direct DB operations raise a transient adapter error" do
    show = shows(:upcoming)
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "pending")

    call_count = 0
    original_find = BatchRun.method(:find)
    BatchRun.define_singleton_method(:find) do |*args|
      call_count += 1
      raise ActiveRecord::ConnectionTimeoutError, "transient boom" if call_count == 1

      original_find.call(*args)
    end

    begin
      assert_enqueued_with(job: BatchRunFanOutJob, args: [ batch_run.id ]) do
        assert_nothing_raised do
          BatchRunFanOutJob.perform_now(batch_run.id)
        end
      end
    ensure
      BatchRun.define_singleton_method(:find, original_find)
    end
  end

  test "an atomic claim lets only one of two racing pending->running transitions succeed" do
    show = shows(:upcoming)
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "pending")

    # Simulates two BatchRunFanOutJob executions racing on the same
    # pending run (e.g. StartBatchRun's resume logic re-enqueuing while
    # the first job is still mid-flight): only one update_all can ever
    # match status: "pending" and flip it.
    first_claimed = BatchRun.where(id: batch_run.id, status: "pending").update_all(status: "running", started_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    second_claimed = BatchRun.where(id: batch_run.id, status: "pending").update_all(status: "running", started_at: Time.current) # rubocop:disable Rails/SkipsModelValidations

    assert_equal 1, first_claimed
    assert_equal 0, second_claimed
  end

  test "a fan-out execution that loses the claim race falls through without touching total_count or creating items" do
    show = shows(:upcoming)
    Person.create!(first_name: "Alice", last_name: "Aardvark", email: "alice-race@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "pending")

    # Simulates a concurrent execution having already won the claim by
    # the time this one runs its own pending? check.
    BatchRun.where(id: batch_run.id, status: "pending").update_all(status: "running", started_at: Time.current) # rubocop:disable Rails/SkipsModelValidations

    assert_no_enqueued_jobs only: BatchRunItemJob do
      BatchRunFanOutJob.perform_now(batch_run.id)
    end

    batch_run.reload
    assert batch_run.running?
    assert_equal 0, batch_run.total_count
    assert_equal 0, batch_run.batch_run_items.count
  end

  test "a genuine bug is not retried -- it raises immediately instead of retrying against a job that will never fix itself" do
    show = shows(:upcoming)
    Person.create!(first_name: "Alice", last_name: "Aardvark", email: "alice-bug@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "pending")

    original_perform_later = BatchRunItemJob.method(:perform_later)
    BatchRunItemJob.define_singleton_method(:perform_later) do |*_args|
      raise NoMethodError, "undefined method (simulated code bug, not a transient adapter error)"
    end

    begin
      assert_no_enqueued_jobs only: BatchRunFanOutJob do
        assert_raises(NoMethodError) do
          BatchRunFanOutJob.perform_now(batch_run.id)
        end
      end
    ensure
      BatchRunItemJob.define_singleton_method(:perform_later, original_perform_later)
    end
  end
end

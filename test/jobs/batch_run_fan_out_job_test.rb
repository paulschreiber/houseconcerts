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

  test "does not recreate items or touch total_count if the recipient phase already completed" do
    show = shows(:upcoming)
    alice = Person.create!(first_name: "Alice", last_name: "Aardvark", email: "alice-done@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1)
    batch_run.batch_run_items.create!(recipient: alice, status: :sent, sent_at: Time.current)

    assert_no_enqueued_jobs only: BatchRunItemJob do
      BatchRunFanOutJob.perform_now(batch_run.id)
    end

    batch_run.reload
    assert_equal 1, batch_run.total_count
    assert_equal 1, batch_run.batch_run_items.count
  end

  test "a failure anywhere during the recipient snapshot rolls back the whole transaction, not just part of it" do
    show = shows(:upcoming)
    Person.create!(first_name: "Alice", last_name: "Aardvark", email: "alice-rollback@example.com", status: "active")
    Person.create!(first_name: "Bob", last_name: "Zebra", email: "bob-rollback@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "pending")

    # Simulates a crash/transient failure on the very last write of the
    # recipient-snapshot phase, after both items were already created
    # (within the same still-open transaction). The whole thing must
    # roll back together -- unlike the old design, where each create!
    # committed individually and durably regardless of what happened
    # next -- so a retry can safely redo the entire phase from scratch
    # instead of finding a half-finished snapshot.
    BatchRun.class_eval do
      alias_method :original_update_for_test, :update!
      define_method(:update!) { |*_args, **_kwargs| raise "simulated failure finalizing the snapshot" }
    end

    begin
      assert_raises(RuntimeError) do
        BatchRunFanOutJob.perform_now(batch_run.id)
      end
    ensure
      BatchRun.class_eval do
        remove_method :update!
        alias_method :update!, :original_update_for_test
        remove_method :original_update_for_test
      end
    end

    batch_run.reload
    assert batch_run.pending?
    assert_equal 0, batch_run.batch_run_items.count

    assert_enqueued_jobs 2, only: BatchRunItemJob do
      BatchRunFanOutJob.perform_now(batch_run.id)
    end
    assert_equal 2, batch_run.reload.total_count
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

  test "does not enqueue a job for an item another fan-out execution already claimed" do
    show = shows(:upcoming)
    person = Person.create!(first_name: "Alice", last_name: "Aardvark", email: "alice-claimed@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1)
    item = batch_run.batch_run_items.create!(recipient: person, status: :pending)

    # Simulates a sibling fan-out execution (e.g. one that lost the
    # with_lock race but still reached the enqueue step) having already
    # claimed this item.
    BatchRunItem.where(id: item.id).update_all(fan_out_enqueued_at: Time.current) # rubocop:disable Rails/SkipsModelValidations

    assert_no_enqueued_jobs only: BatchRunItemJob do
      BatchRunFanOutJob.perform_now(batch_run.id)
    end
  end

  test "releases an item's enqueue claim if perform_later raises, so a later scan can retry it" do
    show = shows(:upcoming)
    person = Person.create!(first_name: "Alice", last_name: "Aardvark", email: "alice-release-claim@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1)
    item = batch_run.batch_run_items.create!(recipient: person, status: :pending)

    original_perform_later = BatchRunItemJob.method(:perform_later)
    BatchRunItemJob.define_singleton_method(:perform_later) do |*_args|
      raise SolidQueue::Job::EnqueueError, "transient boom"
    end

    begin
      assert_nothing_raised do
        BatchRunFanOutJob.perform_now(batch_run.id)
      end
    ensure
      BatchRunItemJob.define_singleton_method(:perform_later, original_perform_later)
    end

    assert_nil item.reload.fan_out_enqueued_at, "the claim should be released, not left stuck, so a retried scan doesn't skip this item forever"
  end

  test "two racing scans that both see an item as pending only let one of them enqueue it" do
    show = shows(:upcoming)
    person = Person.create!(first_name: "Alice", last_name: "Aardvark", email: "alice-duplicate-race@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1)
    item = batch_run.batch_run_items.create!(recipient: person, status: :pending)

    # Simulates two fan-out executions racing to enqueue the same still-
    # "pending" item (e.g. a winner and a with_lock loser that both reach
    # the enqueue step): only the first claim can succeed, so the second
    # scan finds nothing left to enqueue. Without this, both scans could
    # enqueue their own BatchRunItemJob for this item; if the first one's
    # send then failed (a status BatchRunItemJob's own claim deliberately
    # leaves reclaimable for legitimate admin retries), the second,
    # already-queued duplicate could later claim and resend it.
    first_claimed = BatchRunItem.where(id: item.id, fan_out_enqueued_at: nil).update_all(fan_out_enqueued_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    second_claimed = BatchRunItem.where(id: item.id, fan_out_enqueued_at: nil).update_all(fan_out_enqueued_at: Time.current) # rubocop:disable Rails/SkipsModelValidations

    assert_equal 1, first_claimed
    assert_equal 0, second_claimed
  end
end

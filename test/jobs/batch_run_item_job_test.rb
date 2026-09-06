require "test_helper"

class BatchRunItemJobTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "invite kind sends the invite, marks the item sent, and updates batch_run counts" do
    show = shows(:upcoming)
    person = Person.create!(first_name: "New", last_name: "Person", email: "new-invite@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1)
    item = batch_run.batch_run_items.create!(recipient: person)

    assert_emails 1 do
      BatchRunItemJob.perform_now(item.id)
    end

    assert item.reload.sent?
    assert_not_nil item.sent_at
    batch_run.reload
    assert_equal 1, batch_run.sent_count
    assert_equal 0, batch_run.failed_count
    assert batch_run.completed?
  end

  test "an invite to a recipient who is no longer active is marked failed, not sent" do
    show = shows(:upcoming)
    person = Person.create!(first_name: "Removed", last_name: "Person", email: "removed@example.com", status: "removed")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1)
    item = batch_run.batch_run_items.create!(recipient: person)

    assert_emails 1 do
      BatchRunItemJob.perform_now(item.id)
    end

    assert item.reload.failed?
    assert_match(/no longer active/, item.error_message)
    batch_run.reload
    assert_equal 0, batch_run.sent_count
    assert_equal 1, batch_run.failed_count
    assert batch_run.completed?
  end

  test "a raised exception marks the item failed and still updates batch_run counts" do
    show = shows(:upcoming)
    person = Person.create!(first_name: "New", last_name: "Person", email: "will-fail@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1)
    item = batch_run.batch_run_items.create!(recipient: person)

    original_invite = InvitesMailer.method(:invite)
    InvitesMailer.define_singleton_method(:invite) { |*| raise "simulated delivery failure" }

    begin
      assert_emails 1 do
        BatchRunItemJob.perform_now(item.id)
      end
    ensure
      InvitesMailer.define_singleton_method(:invite, original_invite)
    end

    assert item.reload.failed?
    assert_equal "simulated delivery failure", item.error_message
    batch_run.reload
    assert_equal 0, batch_run.sent_count
    assert_equal 1, batch_run.failed_count
    assert batch_run.completed?
  end

  test "a non-pending item is a no-op" do
    show = shows(:upcoming)
    person = Person.create!(first_name: "Already", last_name: "Sent", email: "already-sent@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1, sent_count: 1)
    item = batch_run.batch_run_items.create!(recipient: person, status: "sent", sent_at: Time.current)

    assert_no_emails do
      BatchRunItemJob.perform_now(item.id)
    end

    batch_run.reload
    assert_equal 1, batch_run.sent_count
    assert_equal 0, batch_run.failed_count
  end

  test "retrying a failed item that now succeeds is freshly counted as sent" do
    show = shows(:upcoming)
    person = Person.create!(first_name: "Retry", last_name: "Success", email: "retry-success@example.com", status: "active")
    # Mirrors what Madmin::ShowsController#retry_failed_batch_run actually sets up:
    # status back to running and failed_count reset to 0 for the items being retried.
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1, failed_count: 0)
    item = batch_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")

    assert_emails 1 do
      BatchRunItemJob.perform_now(item.id)
    end

    assert item.reload.sent?
    assert_nil item.error_message
    batch_run.reload
    assert_equal 1, batch_run.sent_count
    assert_equal 0, batch_run.failed_count
    assert batch_run.completed?
  end

  test "retrying a failed item that fails again is freshly counted as failed and re-notifies the admin" do
    show = shows(:upcoming)
    person = Person.create!(first_name: "Retry", last_name: "Failure", email: "retry-failure@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1, failed_count: 0)
    item = batch_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")

    original_invite = InvitesMailer.method(:invite)
    InvitesMailer.define_singleton_method(:invite) { |*| raise "boom again" }

    begin
      # No InvitesMailer email (it fails again), but the run completes
      # with a failure present, so the admin-notification email fires --
      # a still-failing item after a retry must keep alerting, not just
      # on its very first failure.
      assert_emails 1 do
        BatchRunItemJob.perform_now(item.id)
      end
    ensure
      InvitesMailer.define_singleton_method(:invite, original_invite)
    end

    assert item.reload.failed?
    assert_equal "boom again", item.error_message
    batch_run.reload
    assert_equal 0, batch_run.sent_count
    assert_equal 1, batch_run.failed_count
    assert batch_run.completed?
  end

  test "retrying multiple failed items does not complete the run until every retry resolves" do
    show = shows(:upcoming)
    person_a = Person.create!(first_name: "Retry", last_name: "Aardvark", email: "retry-a@example.com", status: "active")
    person_b = Person.create!(first_name: "Retry", last_name: "Baboon", email: "retry-b@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 2, failed_count: 0)
    item_a = batch_run.batch_run_items.create!(recipient: person_a, status: "failed", error_message: "boom")
    item_b = batch_run.batch_run_items.create!(recipient: person_b, status: "failed", error_message: "boom")

    original_invite = InvitesMailer.method(:invite)
    InvitesMailer.define_singleton_method(:invite) do |person, *rest|
      raise "boom again" if person == person_b

      original_invite.call(person, *rest)
    end

    begin
      # item_a's retry succeeds -- just the InvitesMailer send, the run
      # can't be complete yet since item_b is still outstanding.
      assert_emails 1 do
        BatchRunItemJob.perform_now(item_a.id)
      end

      batch_run.reload
      assert batch_run.running?, "the run must not complete while item_b's retry is still outstanding"
      assert_equal 1, batch_run.sent_count
      assert_equal 0, batch_run.failed_count

      # item_b's retry fails again -- no InvitesMailer send, but the run
      # now completes with a failure present, so the admin notification
      # fires exactly once, not once per retried item.
      assert_emails 1 do
        BatchRunItemJob.perform_now(item_b.id)
      end
    ensure
      InvitesMailer.define_singleton_method(:invite, original_invite)
    end

    batch_run.reload
    assert batch_run.completed?
    assert_equal 1, batch_run.sent_count
    assert_equal 1, batch_run.failed_count
  end

  test "a deleted item is a no-op instead of raising" do
    show = shows(:upcoming)
    person = Person.create!(first_name: "Deleted", last_name: "Item", email: "deleted-item@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1)
    item = batch_run.batch_run_items.create!(recipient: person)
    item_id = item.id
    item.destroy!

    assert_no_emails do
      assert_nothing_raised do
        BatchRunItemJob.perform_now(item_id)
      end
    end
  end

  test "an item whose recipient was deleted before the job ran is marked failed with a clear message" do
    show = shows(:upcoming)
    person = Person.create!(first_name: "Deleted", last_name: "Recipient", email: "deleted-before-send@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1)
    item = batch_run.batch_run_items.create!(recipient: person)
    person.destroy!

    # 1 email: the admin failure-notification (total_count 1, so this
    # single failure completes the run), not an InvitesMailer send.
    assert_emails 1 do
      BatchRunItemJob.perform_now(item.id)
    end

    assert item.reload.failed?
    assert_equal "recipient no longer exists", item.error_message
  end

  test "redelivering the same job (e.g. after a worker crash) does not resend" do
    show = shows(:upcoming)
    person = Person.create!(first_name: "New", last_name: "Person", email: "redelivered@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1)
    item = batch_run.batch_run_items.create!(recipient: person)

    assert_emails 1 do
      BatchRunItemJob.perform_now(item.id)
      BatchRunItemJob.perform_now(item.id) # Solid Queue redelivering the same job
    end
  end

  test "completing a batch run with zero failures does not notify the admin" do
    show = shows(:upcoming)
    person_a = Person.create!(first_name: "Clean", last_name: "One", email: "clean-one@example.com", status: "active")
    person_b = Person.create!(first_name: "Clean", last_name: "Two", email: "clean-two@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 2)
    item_a = batch_run.batch_run_items.create!(recipient: person_a)
    item_b = batch_run.batch_run_items.create!(recipient: person_b)

    assert_emails 2 do
      BatchRunItemJob.perform_now(item_a.id)
      BatchRunItemJob.perform_now(item_b.id)
    end

    assert batch_run.reload.completed?
    assert_equal 0, batch_run.failed_count
  end

  test "completing a batch run with a failure notifies the admin exactly once" do
    show = shows(:upcoming)
    person_a = Person.create!(first_name: "Fails", last_name: "One", email: "fails-one@example.com", status: "active")
    person_b = Person.create!(first_name: "Succeeds", last_name: "Two", email: "succeeds-two@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 2)
    item_a = batch_run.batch_run_items.create!(recipient: person_a)
    item_b = batch_run.batch_run_items.create!(recipient: person_b)

    original_invite = InvitesMailer.method(:invite)
    InvitesMailer.define_singleton_method(:invite) do |person, *rest|
      raise "simulated delivery failure" if person == person_a

      original_invite.call(person, *rest)
    end

    begin
      # 1 InvitesMailer send for person_b + 1 NotifyMailer failure notification.
      assert_emails 2 do
        BatchRunItemJob.perform_now(item_a.id)
        BatchRunItemJob.perform_now(item_b.id)
      end
    ensure
      InvitesMailer.define_singleton_method(:invite, original_invite)
    end

    assert batch_run.reload.completed?
    assert_equal 1, batch_run.failed_count
    assert_equal 1, batch_run.sent_count
  end

  test "remind kind sends the reminder email" do
    batch_run = BatchRun.create!(show: shows(:upcoming), kind: "remind", status: "running", total_count: 1)
    item = batch_run.batch_run_items.create!(recipient: rsvps(:one))

    assert_emails 1 do
      BatchRunItemJob.perform_now(item.id)
    end

    assert item.reload.sent?
  end

  test "a reminder to an RSVP that's no longer a confirmed yes attendee is marked failed, not sent" do
    show = shows(:upcoming)
    rsvp = RSVP.create!(show: show, email: "waitlisted-by-now@example.com", first_name: "No", last_name: "Longer",
                        response: "yes", confirmed: "yes", seats_reserved: 1)
    # Bypasses callbacks (incl. the admin RSVP-change notification, which
    # isn't what this test is about) to simulate the RSVP having been
    # waitlisted after the batch snapshot but before this job ran.
    rsvp.update_column(:confirmed, "waitlisted") # rubocop:disable Rails/SkipsModelValidations
    batch_run = BatchRun.create!(show: show, kind: "remind", status: "running", total_count: 1)
    item = batch_run.batch_run_items.create!(recipient: rsvp)

    # 1 email: not the reminder itself, but the admin failure-notification
    # (total_count 1, so this single failure completes the run).
    assert_emails 1 do
      BatchRunItemJob.perform_now(item.id)
    end

    assert item.reload.failed?
    assert_match(/no longer a confirmed yes attendee/, item.error_message)
    batch_run.reload
    assert_equal 0, batch_run.sent_count
    assert_equal 1, batch_run.failed_count
  end

  test "retrying a reminder whose email already went out does not resend the email, only the SMS" do
    show = shows(:upcoming)
    rsvp = RSVP.create!(show: show, email: "retry-remind@example.com", first_name: "Retry", last_name: "Remind",
                        response: "yes", confirmed: "yes", seats_reserved: 1, phone_number: "5555550123")
    batch_run = BatchRun.create!(show: show, kind: "remind", status: "running", total_count: 1, failed_count: 0)
    # Mirrors the state after a first attempt where the reminder email
    # succeeded but the SMS step failed: email_sent_at is already set,
    # and the item is claimable again via its failed status.
    item = batch_run.batch_run_items.create!(recipient: rsvp, status: "failed", error_message: "Twilio boom", email_sent_at: 1.hour.ago)

    assert_no_emails do
      BatchRunItemJob.perform_now(item.id)
    end

    item.reload
    assert item.sent?
    assert_not_nil item.sms_sent_at, "the SMS step should still have been attempted and recorded"
    batch_run.reload
    assert_equal 1, batch_run.sent_count
    assert_equal 0, batch_run.failed_count
  end

  test "retrying an item whose email and SMS already both went out does not resend either" do
    show = shows(:upcoming)
    rsvp = RSVP.create!(show: show, email: "retry-both-sent@example.com", first_name: "Retry", last_name: "Both",
                        response: "yes", confirmed: "yes", seats_reserved: 1, phone_number: "5555550123")
    batch_run = BatchRun.create!(show: show, kind: "remind", status: "running", total_count: 1, failed_count: 0)
    original_sms_sent_at = 1.hour.ago
    # Mirrors a retry triggered after both channels already succeeded
    # (e.g. the item was marked failed for an unrelated reason after both
    # completed): neither channel should be re-attempted.
    item = batch_run.batch_run_items.create!(recipient: rsvp, status: "failed", error_message: "boom",
                                             email_sent_at: 1.hour.ago, sms_sent_at: original_sms_sent_at)

    assert_no_emails do
      BatchRunItemJob.perform_now(item.id)
    end

    item.reload
    assert item.sent?
    assert_in_delta original_sms_sent_at, item.sms_sent_at, 1, "sms_sent_at should be untouched, not refreshed by a skipped resend"
  end

  test "a transient error marking a failed send is retried locally instead of leaving the item mislabeled sent" do
    show = shows(:upcoming)
    original_invite = InvitesMailer.method(:invite)
    InvitesMailer.define_singleton_method(:invite) { |*| raise "delivery boom" }
    person = Person.create!(first_name: "Transient", last_name: "Failure", email: "transient-fail@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1)
    item = batch_run.batch_run_items.create!(recipient: person)

    call_count = 0
    original_update = BatchRunItem.instance_method(:update!)
    BatchRunItem.define_method(:update!) do |*args, **kwargs|
      call_count += 1
      raise ActiveRecord::ConnectionTimeoutError, "transient boom" if call_count == 1

      original_update.bind(self).call(*args, **kwargs)
    end

    begin
      assert_nothing_raised do
        BatchRunItemJob.perform_now(item.id)
      end
    ensure
      InvitesMailer.define_singleton_method(:invite, original_invite)
      BatchRunItem.define_method(:update!, original_update)
    end

    # Correctly marked failed (not stuck showing "sent" despite the
    # delivery never succeeding), and the run's counters reflect it.
    item.reload
    assert item.failed?
    assert_equal "delivery boom", item.error_message
    batch_run.reload
    assert_equal 0, batch_run.sent_count
    assert_equal 1, batch_run.failed_count
  end

  test "a transient error in record_progress is retried locally instead of permanently undercounting the run" do
    show = shows(:upcoming)
    person = Person.create!(first_name: "New", last_name: "Person", email: "transient-progress@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1)
    item = batch_run.batch_run_items.create!(recipient: person)

    call_count = 0
    original_increment = BatchRun.method(:increment_counter)
    BatchRun.define_singleton_method(:increment_counter) do |*args|
      call_count += 1
      raise ActiveRecord::ConnectionTimeoutError, "transient boom" if call_count == 1

      original_increment.call(*args)
    end

    begin
      assert_emails 1 do
        BatchRunItemJob.perform_now(item.id)
      end
    ensure
      BatchRun.define_singleton_method(:increment_counter, original_increment)
    end

    item.reload
    assert item.sent?
    batch_run.reload
    assert_equal 1, batch_run.sent_count
    assert batch_run.completed?
  end

  test "a transient error after the counter increment already succeeded does not double-count on retry" do
    show = shows(:upcoming)
    person = Person.create!(first_name: "New", last_name: "Person", email: "transient-after-increment@example.com", status: "active")
    batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1)
    item = batch_run.batch_run_items.create!(recipient: person)

    # Simulates the increment succeeding and then the very next
    # operation (reload) failing transiently -- record_progress retries
    # only the reload/completion-check/broadcast portion in that case,
    # not the increment, so it must not run a second time.
    call_count = 0
    original_reload = BatchRun.instance_method(:reload)
    BatchRun.define_method(:reload) do |*args|
      call_count += 1
      raise ActiveRecord::ConnectionTimeoutError, "transient boom" if call_count == 1

      original_reload.bind(self).call(*args)
    end

    begin
      assert_emails 1 do
        BatchRunItemJob.perform_now(item.id)
      end
    ensure
      BatchRun.define_method(:reload, original_reload)
    end

    item.reload
    assert item.sent?
    batch_run.reload
    assert_equal 1, batch_run.sent_count, "the counter must not be double-incremented by retrying a failure that happened after it already succeeded"
    assert batch_run.completed?
  end
end

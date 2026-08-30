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
end

require "test_helper"

class ScheduledRemindersJobTest < ActiveSupport::TestCase
  include BatchTestHelpers
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  setup do
    create_run(status: "completed", sent_count: 1, completed_at: 1.day.ago)
  end

  test "starts an automatic remind run at the show's reminder time and emails the admin" do
    assert_enqueued_email_with NotifyMailer, :auto_reminders_started, args: ->(args) { args.first.show == show } do
      run_job
    end

    batch_run = show.batch_runs.remind.sole
    assert batch_run.automatic?
    assert_not_nil show.reload.auto_remind_attempted_at
  end

  test "does nothing before the reminder time" do
    assert_no_enqueued_emails { run_job(at: show.reminder_time - 1.minute) }

    assert_not show.batch_runs.remind.exists?
    assert_nil show.reload.auto_remind_attempted_at
  end

  test "catches up when the reminder time passed without a run, until the show starts" do
    run_job(at: show.start - 1.minute)

    assert show.batch_runs.remind.exists?
  end

  test "starts each show only once" do
    run_job
    complete_remind_run

    assert_no_enqueued_emails { run_job }

    assert_equal 1, show.batch_runs.remind.count
  end

  test "skips a show another run has already claimed" do
    show.update_column(:auto_remind_attempted_at, Time.current) # rubocop:disable Rails/SkipsModelValidations

    assert_no_enqueued_emails { run_job }

    assert_not show.batch_runs.remind.exists?
  end

  test "skips cancelled and unconfirmed shows" do
    %w[cancelled unconfirmed].each do |status|
      show.update!(status:)

      run_job

      assert_not show.batch_runs.remind.exists?, status
    end
  end

  test "skips a show whose reminders were already sent or cancelled by hand" do
    create_run(kind: "remind", status: "completed", sent_count: 0, completed_at: 1.day.ago)

    assert_no_enqueued_emails { run_job }

    assert_equal 1, show.batch_runs.remind.count
    assert_nil show.reload.auto_remind_attempted_at
  end

  test "skips a show whose reminders are already running" do
    create_run(kind: "remind", status: "running")

    assert_no_enqueued_emails { run_job }
  end

  test "resumes a pending remind run" do
    pending_run = create_run(kind: "remind", status: "pending", total_count: 0)

    assert_enqueued_with(job: BatchRunFanOutJob, args: [ pending_run.id ]) { run_job }

    assert_equal [ pending_run ], show.batch_runs.remind.to_a
    assert_enqueued_email_with NotifyMailer, :auto_reminders_started, args: [ pending_run ]
  end

  test "emails once and doesn't retry when invites haven't gone out" do
    BatchRun.invite.delete_all

    assert_emails(1) { run_job }
    assert_includes ActionMailer::Base.deliveries.last.body.encoded, "won’t be tried again"

    assert_no_emails { run_job }

    assert_not show.batch_runs.remind.exists?
    assert_not_nil show.reload.auto_remind_attempted_at
  end

  test "emails once when enqueuing fails, retries quietly, then starts" do
    with_stubbed(BatchRunFanOutJob, :perform_later, ->(*_args) { raise SolidQueue::Job::EnqueueError, "transient boom" }) do
      assert_emails(1) { run_job }
      assert_includes ActionMailer::Base.deliveries.last.body.encoded, "tried again automatically"
      assert_nil show.reload.auto_remind_attempted_at

      assert_no_emails { run_job }
    end

    assert_enqueued_email_with NotifyMailer, :auto_reminders_started, args: ->(args) { args.first.show == show } do
      run_job
    end

    batch_run = show.batch_runs.remind.sole
    assert batch_run.automatic?
    assert_not_nil show.reload.auto_remind_attempted_at
  end

  test "waits for a run from before a reschedule to finish, then starts" do
    old_run = create_run(kind: "remind", status: "running", created_at: 1.day.ago)
    show.update!(start: show.start + 1.week, end: nil)

    assert_no_enqueued_emails { run_job }
    assert_nil show.reload.auto_remind_attempted_at

    complete_remind_run(old_run)
    run_job

    assert show.batch_runs.remind.where.not(id: old_run.id).sole.automatic?
  end

  test "releases the claim and raises on an unexpected error" do
    with_stubbed(StartBatchRun, :call, ->(**_args) { raise "boom" }) do
      assert_raises(RuntimeError) { run_job }
    end

    assert_nil show.reload.auto_remind_attempted_at
  end

  test "sends again for a rescheduled show" do
    run_job
    complete_remind_run

    travel_to show.reminder_time + 1.hour do
      show.update!(start: show.start + 1.week, end: nil)
    end

    run_job

    assert_equal 2, show.batch_runs.remind.count
  end

  private

    # Runs the job as it would run at time, by default the show's current
    # reminder time.
    def run_job(at: show.reminder_time)
      travel_to(at) { ScheduledRemindersJob.perform_now }
    end

    def complete_remind_run(batch_run = show.batch_runs.remind.sole)
      batch_run.update!(status: :completed, completed_at: Time.current)
    end
end

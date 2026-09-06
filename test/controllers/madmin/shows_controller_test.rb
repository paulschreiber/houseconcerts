require "test_helper"

module Madmin
  class ShowsControllerTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper

    setup do
      sign_in admins(:one)
    end

    test "index renders successfully" do
      get madmin_shows_path

      assert_response :success
    end

    test "show renders successfully" do
      get madmin_show_path(shows(:upcoming))

      assert_response :success
    end

    test "edit renders successfully" do
      get edit_madmin_show_path(shows(:upcoming))

      assert_response :success
    end

    test "new renders successfully" do
      get new_madmin_show_path

      assert_response :success
    end

    test "send_invites starts a batch run for the next show and redirects with a notice" do
      show = shows(:upcoming)
      assert show.next_show?

      assert_difference("BatchRun.count", 1) do
        patch send_invites_madmin_show_path(show)
      end

      assert_equal "invite", BatchRun.last.kind
      assert_redirected_to madmin_show_path(show)
      assert_match(/Started sending invites/, flash[:notice])
    end

    test "send_invites redirects with an alert instead of double-sending when a run is already in progress" do
      show = shows(:upcoming)
      BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1)

      assert_no_difference("BatchRun.count") do
        patch send_invites_madmin_show_path(show)
      end

      assert_redirected_to madmin_show_path(show)
      assert_match(/Already sending invites/, flash[:alert])
    end

    test "send_invites redirects with a friendly alert instead of a raw error when the fan-out job fails to enqueue" do
      show = shows(:upcoming)

      original_perform_later = BatchRunFanOutJob.method(:perform_later)
      BatchRunFanOutJob.define_singleton_method(:perform_later) do |*_args|
        raise SolidQueue::Job::EnqueueError, "transient boom"
      end

      begin
        patch send_invites_madmin_show_path(show)
      ensure
        BatchRunFanOutJob.define_singleton_method(:perform_later, original_perform_later)
      end

      assert_redirected_to madmin_show_path(show)
      assert_match(/try again/, flash[:alert])
    end

    test "send_invites_unopened starts a batch run once invites have already been sent" do
      show = shows(:upcoming)
      BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, sent_count: 1)

      assert_difference("BatchRun.count", 1) do
        patch send_invites_unopened_madmin_show_path(show)
      end

      assert_equal "invite_unopened", BatchRun.last.kind
    end

    test "send_invites_unopened refuses a show that has not had invites sent yet" do
      show = shows(:upcoming)
      assert_not show.invites_sent?

      assert_no_difference("BatchRun.count") do
        patch send_invites_unopened_madmin_show_path(show)
      end

      assert_redirected_to madmin_show_path(show)
      assert_match(/Send the initial invites before sending/, flash[:alert])
    end

    test "send_reminders starts a batch run once invites have already been sent" do
      show = shows(:upcoming)
      BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, sent_count: 1)

      assert_difference("BatchRun.count", 1) do
        patch send_reminders_madmin_show_path(show)
      end

      assert_equal "remind", BatchRun.last.kind
    end

    test "send_reminders refuses a show that has not had invites sent yet" do
      show = shows(:upcoming)
      assert_not show.invites_sent?

      assert_no_difference("BatchRun.count") do
        patch send_reminders_madmin_show_path(show)
      end

      assert_redirected_to madmin_show_path(show)
      assert_match(/Send the initial invites before sending/, flash[:alert])
    end

    test "send_invites refuses a show that is not the next show" do
      show = shows(:sold_out)
      assert_not show.next_show?

      assert_no_difference("BatchRun.count") do
        patch send_invites_madmin_show_path(show)
      end

      assert_redirected_to madmin_show_path(show)
      assert_match(/Only the next show/, flash[:alert])
    end

    test "send_reminders reports the next-show restriction, not the invites-sent one, for a show that fails both" do
      show = shows(:sold_out)
      assert_not show.next_show?
      assert_not show.invites_sent?

      assert_no_difference("BatchRun.count") do
        patch send_reminders_madmin_show_path(show)
      end

      assert_redirected_to madmin_show_path(show)
      assert_match(/Only the next show/, flash[:alert])
    end

    test "show page renders the batch buttons for the next show, with Send to Unopened and Send Reminders disabled" do
      get madmin_show_path(shows(:upcoming))

      assert_response :success
      assert_match(/>Send Invites</, response.body)
      assert_match(/>Send to Unopened</, response.body)
      assert_match(/>Send Reminders</, response.body)
      assert_select "button", text: "Send Invites", count: 1 do |buttons|
        assert_nil buttons.first["disabled"]
      end
      assert_select "button", text: "Send to Unopened", count: 1 do |buttons|
        assert buttons.first["disabled"]
      end
      assert_select "button", text: "Send Reminders", count: 1 do |buttons|
        assert buttons.first["disabled"]
      end
    end

    test "show page enables Send to Unopened and Send Reminders once invites have been sent" do
      show = shows(:upcoming)
      BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, sent_count: 1)

      get madmin_show_path(show)

      assert_response :success
      assert_select "button", text: "Send to Unopened", count: 1 do |buttons|
        assert_nil buttons.first["disabled"]
      end
      assert_select "button", text: "Send Reminders", count: 1 do |buttons|
        assert_nil buttons.first["disabled"]
      end
    end

    test "show page hides the progress bar once a batch run has completed" do
      show = shows(:upcoming)
      BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, sent_count: 1)

      get madmin_show_path(show)

      assert_response :success
      assert_select "#batch_run_progress_invite progress", count: 0
      assert_select "#batch_run_progress_invite", text: /1 sent \(complete\)/
    end

    test "show page still shows the progress bar for a batch run in progress" do
      show = shows(:upcoming)
      BatchRun.create!(show: show, kind: "remind", status: "running", total_count: 3, sent_count: 1)

      get madmin_show_path(show)

      assert_response :success
      assert_select "#batch_run_progress_remind progress", count: 1
    end

    test "show page's running progress text labels only actual sends as sent, not sends plus failures" do
      show = shows(:upcoming)
      person = Person.create!(first_name: "Failed", last_name: "Item", email: "running-label-failed@example.com", status: "active")
      batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 3, sent_count: 1, failed_count: 1)
      batch_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")

      get madmin_show_path(show)

      assert_response :success
      assert_select "#batch_run_progress_invite", text: %r{1/3 sent, 1 failed}
    end

    test "show page shows a retry button when a batch run has failed items" do
      show = shows(:upcoming)
      BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 2, sent_count: 1, failed_count: 1)

      get madmin_show_path(show)

      assert_response :success
      assert_select "#batch_run_progress_invite button", text: "Retry 1 failed"
    end

    test "show page has no retry button when there are no failed items" do
      show = shows(:upcoming)
      BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, sent_count: 1)

      get madmin_show_path(show)

      assert_response :success
      assert_select "#batch_run_progress_invite button", text: /Retry/, count: 0
    end

    test "show page still shows a retry button when failed_count says zero but failed items actually exist" do
      show = shows(:upcoming)
      person = Person.create!(first_name: "Retry", last_name: "Stranded", email: "retry-stranded-view@example.com", status: "active")
      # Simulates the aggregate counter and the real rows disagreeing --
      # e.g. a previous retry's own job enqueue failed after failed_count
      # was already reset to 0, leaving this item still genuinely failed.
      batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1, failed_count: 0)
      batch_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")

      get madmin_show_path(show)

      assert_response :success
      assert_select "#batch_run_progress_invite button", text: "Retry 1 failed"
    end

    test "retry_failed_batch_run still works when failed_count says zero but failed items actually exist" do
      show = shows(:upcoming)
      person = Person.create!(first_name: "Retry", last_name: "Stranded", email: "retry-stranded@example.com", status: "active")
      batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1, failed_count: 0)
      batch_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")

      assert_enqueued_with(job: BatchRunRetryFanOutJob, args: [ batch_run.id ]) do
        patch retry_failed_batch_run_madmin_show_path(show, batch_run_id: batch_run.id)
      end

      assert_redirected_to madmin_show_path(show)
      assert_match(/Retrying 1 failed invites/, flash[:notice])
    end

    test "retry_failed_batch_run re-enqueues failed items and reopens the run" do
      show = shows(:upcoming)
      person = Person.create!(first_name: "Retry", last_name: "Me", email: "retry-me@example.com", status: "active")
      batch_run = BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, failed_count: 1, completed_at: Time.current)
      batch_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")

      assert_enqueued_with(job: BatchRunRetryFanOutJob, args: [ batch_run.id ]) do
        patch retry_failed_batch_run_madmin_show_path(show, batch_run_id: batch_run.id)
      end

      batch_run.reload
      assert batch_run.running?
      assert_nil batch_run.completed_at
      assert_redirected_to madmin_show_path(show)
      assert_match(/Retrying 1 failed invites/, flash[:notice])
    end

    test "retry_failed_batch_run resets failed_count so the run doesn't look complete before the retries resolve" do
      show = shows(:upcoming)
      person_a = Person.create!(first_name: "Retry", last_name: "Aardvark", email: "retry-a@example.com", status: "active")
      person_b = Person.create!(first_name: "Retry", last_name: "Baboon", email: "retry-b@example.com", status: "active")
      batch_run = BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 2, failed_count: 2, completed_at: Time.current)
      batch_run.batch_run_items.create!(recipient: person_a, status: "failed", error_message: "boom")
      batch_run.batch_run_items.create!(recipient: person_b, status: "failed", error_message: "boom")

      patch retry_failed_batch_run_madmin_show_path(show, batch_run_id: batch_run.id)

      batch_run.reload
      assert batch_run.running?
      assert_equal 0, batch_run.failed_count, "failed_count must be reset so a single resolved retry can't look like the whole run finished"
    end

    test "retry_failed_batch_run refuses a batch_run_id that doesn't belong to this show instead of raising" do
      show = shows(:upcoming)
      other_show_batch_run = BatchRun.create!(show: shows(:sold_out), kind: "invite", status: "completed", total_count: 1, failed_count: 1)

      assert_no_enqueued_jobs do
        patch retry_failed_batch_run_madmin_show_path(show, batch_run_id: other_show_batch_run.id)
      end

      assert_redirected_to madmin_show_path(show)
      assert_match(/no failed batch sends to retry/, flash[:alert])
    end

    test "retry_failed_batch_run redirects with an alert when there is nothing to retry" do
      show = shows(:upcoming)
      batch_run = BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, sent_count: 1)

      assert_no_enqueued_jobs do
        patch retry_failed_batch_run_madmin_show_path(show, batch_run_id: batch_run.id)
      end

      assert_redirected_to madmin_show_path(show)
      assert_match(/no failed invites sends to retry/, flash[:alert])
    end

    test "retry_failed_batch_run can retry an older run's failures even after a newer failure-free run of the same kind exists" do
      show = shows(:upcoming)
      person = Person.create!(first_name: "Retry", last_name: "Old", email: "retry-old@example.com", status: "active")
      old_run = BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, failed_count: 1, completed_at: 1.day.ago)
      old_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")
      BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, sent_count: 1, completed_at: Time.current)

      assert_enqueued_with(job: BatchRunRetryFanOutJob, args: [ old_run.id ]) do
        patch retry_failed_batch_run_madmin_show_path(show, batch_run_id: old_run.id)
      end

      assert_redirected_to madmin_show_path(show)
      assert old_run.reload.running?
    end

    test "retry_failed_batch_run redirects gracefully instead of raising when a newer run of the same kind is active" do
      show = shows(:upcoming)
      person = Person.create!(first_name: "Retry", last_name: "Collide", email: "retry-collide@example.com", status: "active")
      old_run = BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, failed_count: 1, completed_at: 1.day.ago)
      old_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")
      # active_kind_lock only allows one non-completed run per show+kind at
      # a time, so reopening old_run to "running" collides with this one.
      BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1)

      assert_no_enqueued_jobs do
        patch retry_failed_batch_run_madmin_show_path(show, batch_run_id: old_run.id)
      end

      assert_redirected_to madmin_show_path(show)
      assert_match(/already in progress/, flash[:alert])
      assert old_run.reload.completed?
    end

    test "retry_failed_batch_run redirects with a friendly alert instead of a raw error when the retry fan-out job fails to enqueue" do
      show = shows(:upcoming)
      person = Person.create!(first_name: "Retry", last_name: "EnqueueFail", email: "retry-enqueue-fail@example.com", status: "active")
      batch_run = BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, failed_count: 1, completed_at: Time.current)
      batch_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")

      original_perform_later = BatchRunRetryFanOutJob.method(:perform_later)
      BatchRunRetryFanOutJob.define_singleton_method(:perform_later) do |*_args|
        raise SolidQueue::Job::EnqueueError, "transient boom"
      end

      begin
        patch retry_failed_batch_run_madmin_show_path(show, batch_run_id: batch_run.id)
      ensure
        BatchRunRetryFanOutJob.define_singleton_method(:perform_later, original_perform_later)
      end

      assert_redirected_to madmin_show_path(show)
      assert_match(/try again/, flash[:alert])
      # The run itself is still correctly reopened -- the button/gate
      # will pick this back up on a later click since they query the
      # real failed items, not the (already-reset) counter.
      assert batch_run.reload.running?
    end

    test "each batch run gets its own stream, so an older run of the same kind can't clobber a newer one's display" do
      show = shows(:upcoming)
      BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, sent_count: 1)
      get madmin_show_path(show)
      first_stream_names = response.body.scan(/signed-stream-name="([^"]+)"/).flatten

      BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1)
      get madmin_show_path(show)
      second_stream_names = response.body.scan(/signed-stream-name="([^"]+)"/).flatten

      assert_empty first_stream_names & second_stream_names
    end

    test "show page hides the batch buttons for a show that is not the next show" do
      get madmin_show_path(shows(:sold_out))

      assert_response :success
      assert_no_match(/>Send Invites</, response.body)
    end

    test "show page has no batch progress section for a show with no batch runs" do
      get madmin_show_path(shows(:sold_out))

      assert_response :success
      assert_select ".batch-progress", count: 0
    end

    test "show page still shows batch history and a retry button for a show that is not the next show" do
      show = shows(:sold_out)
      person = Person.create!(first_name: "Retry", last_name: "PastShow", email: "retry-past-show@example.com", status: "active")
      batch_run = BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, failed_count: 1, completed_at: Time.current)
      batch_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")

      get madmin_show_path(show)

      assert_response :success
      assert_no_match(/>Send Invites</, response.body)
      assert_select "#batch_run_progress_invite button", text: "Retry 1 failed"
    end

    test "batch progress shows and subscribes to a retried older run, not a newer completed run of the same kind" do
      show = shows(:upcoming)
      person = Person.create!(first_name: "Retry", last_name: "Reopen", email: "retry-reopen@example.com", status: "active")
      old_run = BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, failed_count: 1, completed_at: 1.day.ago)
      old_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")
      newer_run = BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, sent_count: 1, completed_at: Time.current)

      patch retry_failed_batch_run_madmin_show_path(show, batch_run_id: old_run.id)
      assert old_run.reload.running?

      get madmin_show_path(show)

      assert_response :success
      assert_select "#batch_run_progress_invite", text: %r{0/1 sent, 1 failed}

      stream_names = response.body.scan(/signed-stream-name="([^"]+)"/).flatten
      assert_includes stream_names, Turbo::StreamsChannel.signed_stream_name([ old_run, :progress ])
      assert_not_includes stream_names, Turbo::StreamsChannel.signed_stream_name([ newer_run, :progress ])
    end

    test "index without a scope sorts shows by start descending" do
      get madmin_shows_path

      assert_response :success
      assert_operator response.body.index(shows(:upcoming).name), :<, response.body.index(shows(:past).name)
    end

    test "index with the upcoming scope sorts shows by start ascending" do
      get madmin_shows_path(scope: "upcoming")

      assert_response :success
      assert_operator response.body.index(shows(:upcoming).name), :<, response.body.index(shows(:sold_out).name)
    end
  end
end

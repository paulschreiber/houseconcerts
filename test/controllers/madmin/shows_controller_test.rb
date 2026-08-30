require "test_helper"

module Madmin
  class ShowsControllerTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper

    setup do
      sign_in admins(:one)
    end

    test "send_invites starts a batch run for the next show and redirects with a notice" do
      show = shows(:upcoming)
      assert show.next_show?

      assert_difference("BatchRun.count", 1) do
        patch send_invites_madmin_show_path(show)
      end

      assert_equal "invite", BatchRun.last.kind
      assert_redirected_to madmin_shows_path
      assert_match(/Started sending invites/, flash[:notice])
    end

    test "send_invites redirects with an alert instead of double-sending when a run is already in progress" do
      show = shows(:upcoming)
      BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1)

      assert_no_difference("BatchRun.count") do
        patch send_invites_madmin_show_path(show)
      end

      assert_redirected_to madmin_shows_path
      assert_match(/Already sending invites/, flash[:alert])
    end

    test "send_invites_unopened starts a batch run once invites have already been sent" do
      show = shows(:upcoming)
      BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 0)

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

      assert_redirected_to madmin_shows_path
      assert_match(/Send the initial invites before sending/, flash[:alert])
    end

    test "send_reminders starts a batch run once invites have already been sent" do
      show = shows(:upcoming)
      BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 0)

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

      assert_redirected_to madmin_shows_path
      assert_match(/Send the initial invites before sending/, flash[:alert])
    end

    test "send_invites refuses a show that is not the next show" do
      show = shows(:sold_out)
      assert_not show.next_show?

      assert_no_difference("BatchRun.count") do
        patch send_invites_madmin_show_path(show)
      end

      assert_redirected_to madmin_shows_path
      assert_match(/Only the next show/, flash[:alert])
    end

    test "send_reminders reports the next-show restriction, not the invites-sent one, for a show that fails both" do
      show = shows(:sold_out)
      assert_not show.next_show?
      assert_not show.invites_sent?

      assert_no_difference("BatchRun.count") do
        patch send_reminders_madmin_show_path(show)
      end

      assert_redirected_to madmin_shows_path
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
      BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 0)

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

    test "retry_failed_batch_run re-enqueues failed items and reopens the run" do
      show = shows(:upcoming)
      person = Person.create!(first_name: "Retry", last_name: "Me", email: "retry-me@example.com", status: "active")
      batch_run = BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, failed_count: 1, completed_at: Time.current)
      batch_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")

      assert_enqueued_with(job: BatchRunItemJob) do
        patch retry_failed_batch_run_madmin_show_path(show, kind: "invite")
      end

      batch_run.reload
      assert batch_run.running?
      assert_nil batch_run.completed_at
      assert_redirected_to madmin_shows_path
      assert_match(/Retrying 1 failed invites/, flash[:notice])
    end

    test "retry_failed_batch_run resets failed_count so the run doesn't look complete before the retries resolve" do
      show = shows(:upcoming)
      person_a = Person.create!(first_name: "Retry", last_name: "Aardvark", email: "retry-a@example.com", status: "active")
      person_b = Person.create!(first_name: "Retry", last_name: "Baboon", email: "retry-b@example.com", status: "active")
      batch_run = BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 2, failed_count: 2, completed_at: Time.current)
      batch_run.batch_run_items.create!(recipient: person_a, status: "failed", error_message: "boom")
      batch_run.batch_run_items.create!(recipient: person_b, status: "failed", error_message: "boom")

      patch retry_failed_batch_run_madmin_show_path(show, kind: "invite")

      batch_run.reload
      assert batch_run.running?
      assert_equal 0, batch_run.failed_count, "failed_count must be reset so a single resolved retry can't look like the whole run finished"
    end

    test "retry_failed_batch_run rejects a kind that isn't a real batch kind instead of raising" do
      show = shows(:upcoming)

      assert_no_enqueued_jobs do
        patch retry_failed_batch_run_madmin_show_path(show, kind: "nonsense")
      end

      assert_redirected_to madmin_shows_path
      assert_match(/Unknown batch kind/, flash[:alert])
    end

    test "retry_failed_batch_run redirects with an alert when there is nothing to retry" do
      show = shows(:upcoming)
      BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, sent_count: 1)

      assert_no_enqueued_jobs do
        patch retry_failed_batch_run_madmin_show_path(show, kind: "invite")
      end

      assert_redirected_to madmin_shows_path
      assert_match(/no failed invites sends to retry/, flash[:alert])
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

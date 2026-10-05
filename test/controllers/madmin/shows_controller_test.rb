require "test_helper"
require "turbo/broadcastable/test_helper"

module Madmin
  class ShowsControllerTest < ActionDispatch::IntegrationTest
    include ActionMailer::TestHelper
    include ActiveJob::TestHelper
    include Turbo::Broadcastable::TestHelper

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

    test "create creates a show and redirects to its show page" do
      start = 2.months.from_now.change(hour: 19, min: 0, sec: 0)

      assert_difference "Show.count", 1 do
        post madmin_shows_path, params: { show: {
          name: "New Show", venue_id: venues(:one).id, price: 20,
          start: start.iso8601, end: (start + 2.hours).iso8601
        } }
      end

      assert_redirected_to madmin_show_path(Show.last)
    end

    test "create with invalid attributes renders new" do
      assert_no_difference "Show.count" do
        post madmin_shows_path, params: { show: { name: "", start: 2.months.from_now.iso8601, venue_id: venues(:one).id, price: 20 } }
      end

      assert_response :unprocessable_content
    end

    test "update updates the show and redirects to its show page" do
      show = shows(:upcoming)

      patch madmin_show_path(show), params: { show: { name: "Updated Show" } }

      assert_equal "Updated Show", show.reload.name
      assert_redirected_to madmin_show_path(show)
    end

    test "update with invalid attributes renders edit" do
      show = shows(:upcoming)

      patch madmin_show_path(show), params: { show: { name: "" } }

      assert_response :unprocessable_content
      assert_equal "Test Upcoming Show", show.reload.name
    end

    test "upcoming scope sorts shows by start ascending by default" do
      soon = Show.create!(name: "Soon Show", venue: venues(:one), price: 20, start: 1.day.from_now, end: 1.day.from_now + 2.hours)
      later = Show.create!(name: "Later Show", venue: venues(:one), price: 20, start: 10.days.from_now, end: 10.days.from_now + 2.hours)
      # created_at ties (same-second precision) would otherwise make this
      # pass by coincidence via insertion-order tiebreaking; force created_at
      # into the opposite order of start so this only passes if the
      # controller actually sorts by start.
      soon.update_column(:created_at, 1.hour.ago) # rubocop:disable Rails/SkipsModelValidations
      later.update_column(:created_at, 1.hour.from_now) # rubocop:disable Rails/SkipsModelValidations

      get madmin_shows_path(scope: "upcoming")

      assert_response :success
      assert_operator response.body.index(soon.name), :<, response.body.index(later.name)
    end

    test "past scope sorts shows by start descending by default" do
      older = Show.create!(name: "Older Show", venue: venues(:one), price: 20, start: 10.days.ago, end: 10.days.ago + 2.hours)
      recent = Show.create!(name: "Recent Show", venue: venues(:one), price: 20, start: 1.day.ago, end: 1.day.ago + 2.hours)
      # created_at ties (same-second precision) would otherwise make this
      # depend on incidental insertion-order tiebreaking; force created_at
      # into the opposite order of start so this only passes if the
      # controller actually sorts by start.
      older.update_column(:created_at, 1.hour.from_now) # rubocop:disable Rails/SkipsModelValidations
      recent.update_column(:created_at, 1.hour.ago) # rubocop:disable Rails/SkipsModelValidations

      get madmin_shows_path(scope: "past")

      assert_response :success
      assert_operator response.body.index(recent.name), :<, response.body.index(older.name)
    end

    test "the all (no scope) view sorts shows by start descending by default" do
      older = Show.create!(name: "Older Show", venue: venues(:one), price: 20, start: 10.days.ago, end: 10.days.ago + 2.hours)
      recent = Show.create!(name: "Recent Show", venue: venues(:one), price: 20, start: 1.day.ago, end: 1.day.ago + 2.hours)
      # created_at ties (same-second precision) would otherwise make this
      # depend on incidental insertion-order tiebreaking; force created_at
      # into the opposite order of start so this only passes if the
      # controller actually sorts by start.
      older.update_column(:created_at, 1.hour.from_now) # rubocop:disable Rails/SkipsModelValidations
      recent.update_column(:created_at, 1.hour.ago) # rubocop:disable Rails/SkipsModelValidations

      get madmin_shows_path

      assert_response :success
      assert_operator response.body.index(recent.name), :<, response.body.index(older.name)
    end

    test "an explicit sort param overrides the scope's default ordering" do
      Show.create!(name: "Soon Show", venue: venues(:one), price: 20, start: 1.day.from_now, end: 1.day.from_now + 2.hours)
      Show.create!(name: "Later Show", venue: venues(:one), price: 20, start: 10.days.from_now, end: 10.days.from_now + 2.hours)

      get madmin_shows_path(scope: "upcoming", sort: "start", direction: "desc")

      assert_response :success
      assert_operator response.body.index("Later Show"), :<, response.body.index("Soon Show")
    end

    test "ShowResource's default sort hooks match the actual default ordering" do
      assert_equal "start", ShowResource.default_sort_column
      assert_equal "desc", ShowResource.default_sort_direction

      Current.set(admin_scope: "upcoming") do
        assert_equal "asc", ShowResource.default_sort_direction
      end
    end

    test "start is labelled Start on the show page and form, and Date only in the index" do
      get madmin_show_path(shows(:past))
      assert_select "th.label", text: "Start"
      assert_select "th.label", text: "Date", count: 0

      get edit_madmin_show_path(shows(:past))
      assert_select "label", text: "Start"
    end

    test "index has a Date column, date only, with the sort arrow on it" do
      get madmin_shows_path

      assert_select "thead th a[href*='sort=start']", text: /Date/ do
        assert_select "svg"
      end
      assert_select "tbody td", text: shows(:past).start.to_date.iso8601
    end

    test "destroy destroys the show and redirects to the index page" do
      show = shows(:past)

      assert_difference "Show.count", -1 do
        delete madmin_show_path(show)
      end

      assert_redirected_to madmin_shows_path
    end

    test "show links to the show's attendance and printable attendee list" do
      get madmin_show_path(shows(:past))

      assert_select "a[href=?]", attendance_madmin_show_path(shows(:past)), text: "Attendance"
      assert_select "a[href=?]", print_attendance_madmin_show_path(shows(:past)), text: "Print Attendance"
    end

    test "index rows link to Print Attendance for upcoming shows and Record Attendance for past ones" do
      get madmin_shows_path(scope: "upcoming")
      assert_select "td.actions a[href=?]", print_attendance_madmin_show_path(shows(:upcoming)), text: "Print Attendance"
      assert_select "td.actions a", text: "Record Attendance", count: 0

      get madmin_shows_path(scope: "past")
      assert_select "td.actions a[href=?]", attendance_madmin_show_path(shows(:past)), text: "Record Attendance"
      assert_select "td.actions a", text: "Print Attendance", count: 0

      get madmin_shows_path
      assert_select "td.actions a", text: /Attendance/, count: 0
    end

    test "show has Nonsubscribers and Add Phone Numbers buttons" do
      get madmin_show_path(shows(:past))

      assert_select "form[action=?] button", add_nonsubscribers_madmin_show_path(shows(:past)), text: "Add Nonsubscribers"
      assert_select "form[action=?] button", add_phone_numbers_madmin_show_path(shows(:past)), text: "Add Phone Numbers"
    end

    test "add_nonsubscribers adds the show's yes RSVPs to the mailing list and says who" do
      attendee(shows(:past), "Jane")
      Person.create!(first_name: "John", last_name: "Smith", email: "john.smith@example.com", status: "removed")
      attendee(shows(:past), "John")

      assert_difference("Person.count", 1) { post add_nonsubscribers_madmin_show_path(shows(:past)) }

      assert_redirected_to madmin_show_path(shows(:past))
      assert_equal "Added Jane Smith to the mailing list. Didn’t re-add John Smith, who unsubscribed, bounced or moved.", flash[:notice]
      assert_predicate Person.find_by(email: "john.smith@example.com"), :removed?
    end

    test "add_nonsubscribers and add_phone_numbers return to the page they were clicked on" do
      get madmin_root_path

      post add_nonsubscribers_madmin_show_path(shows(:past)), headers: { "HTTP_REFERER" => madmin_root_url }
      assert_redirected_to madmin_root_url

      post add_phone_numbers_madmin_show_path(shows(:past)), headers: { "HTTP_REFERER" => madmin_root_url }
      assert_redirected_to madmin_root_url
    end

    test "add_nonsubscribers reports someone who couldn't be added as an error" do
      attendee(shows(:past), "Jane").update_column(:first_name, "J") # rubocop:disable Rails/SkipsModelValidations

      post add_nonsubscribers_madmin_show_path(shows(:past))

      assert_match(/\ACouldn’t add J Smith \(.+\)\.\z/, flash[:alert])
      assert_nil flash[:notice]
    end

    test "add_nonsubscribers says so when there's no one to add" do
      post add_nonsubscribers_madmin_show_path(shows(:past))

      assert_equal "Everyone who RSVPd yes is already on the mailing list.", flash[:notice]
    end

    test "add_phone_numbers fills in missing phone numbers from the show's RSVPs" do
      attendee(shows(:past), "Jane", phone_number: "2125551234")
      person = Person.create!(first_name: "Jane", last_name: "Smith", email: "jane.smith@example.com")

      post add_phone_numbers_madmin_show_path(shows(:past))

      assert_redirected_to madmin_show_path(shows(:past))
      assert_equal "Added phone numbers for Jane Smith.", flash[:notice]
      assert_predicate person.reload.phone_number, :present?

      post add_phone_numbers_madmin_show_path(shows(:past))
      assert_equal "No phone numbers to add.", flash[:notice]
    end

    test "print_attendance lists the show's attendees and totals" do
      rsvp = attendee(shows(:upcoming), "Jane", seats_reserved: 2, phone_number: "2125551234")

      get print_attendance_madmin_show_path(shows(:upcoming))

      assert_response :success
      assert_match shows(:upcoming).name, response.body
      cells = attendee_row_cells(rsvp.full_name)
      assert_equal "(212) 555-1234", cells[1].text
      assert_equal "2", cells[2].text
      assert_equal "✖", cells[3].text
      assert_equal "✖", cells[4].text
      assert_match(%r{Seats</h4>\s*<p>#{RSVP.attendees(shows(:upcoming)).sum(:seats_reserved)}<}, response.body)
    end

    test "print_attendance flags someone on the mailing list who attended an earlier show" do
      rsvp = attendee(shows(:upcoming), "Test", email: people(:one).email)
      attendee(shows(:past), "Test", email: people(:one).email)

      get print_attendance_madmin_show_path(shows(:upcoming))

      cells = attendee_row_cells(rsvp.full_name)
      assert_equal "✔", cells[3].text
      assert_equal "✔", cells[4].text
    end

    test "print_attendance doesn't count the show itself as attending before" do
      rsvp = attendee(shows(:past), "Jane")

      get print_attendance_madmin_show_path(shows(:past))

      assert_equal "✖", attendee_row_cells(rsvp.full_name)[4].text
    end

    test "print_attendance leaves out RSVPs that aren't a confirmed yes" do
      rsvp = attendee(shows(:past), "Jane")
      rsvp.update!(confirmed: "unconfirmed")

      get print_attendance_madmin_show_path(shows(:past))

      assert_response :success
      assert_no_match(/Jane Smith/, response.body)
    end

    test "attendance lists the show's attendees with seats used prefilled" do
      unrecorded = attendee(shows(:past), "Jane", seats_reserved: 3)
      recorded = attendee(shows(:past), "John", seats_reserved: 2, seats_used: 1)
      other_show = attendee(shows(:upcoming), "Joan")

      get attendance_madmin_show_path(shows(:past))

      assert_response :success
      assert_select "input[name=?][value=?]", "seats_used[#{unrecorded.id}]", "3"
      assert_select "input[name=?][value=?]", "seats_used[#{recorded.id}]", "1"
      assert_select "input[name=?]", "seats_used[#{other_show.id}]", count: 0
    end

    test "attendance works for any show, not just the most recent one" do
      older = Show.create!(name: "Older Show", venue: venues(:one), start: 3.months.ago, price: 20, blurb: "An older show.")
      rsvp = attendee(older, "Jane", seats_reserved: 2)

      patch attendance_madmin_show_path(older), params: { seats_used: { rsvp.id => "2" } }

      assert_redirected_to attendance_madmin_show_path(older)
      assert_equal 2, rsvp.reload.seats_used
    end

    test "update_attendance saves seats used without emailing the admin" do
      jane = attendee(shows(:past), "Jane", seats_reserved: 3)
      john = attendee(shows(:past), "John", seats_reserved: 2)

      assert_no_enqueued_emails do
        patch attendance_madmin_show_path(shows(:past)), params: { seats_used: { jane.id => "3", john.id => "0" } }
      end

      assert_redirected_to attendance_madmin_show_path(shows(:past))
      assert_equal 3, jane.reload.seats_used
      assert_equal 0, john.reload.seats_used
    end

    test "update_attendance ignores RSVPs for other shows" do
      other_show = attendee(shows(:upcoming), "Joan")

      patch attendance_madmin_show_path(shows(:past)), params: { seats_used: { other_show.id => "1" } }

      assert_nil other_show.reload.seats_used
    end

    test "update_attendance saves nothing when any value is invalid" do
      jane = attendee(shows(:past), "Jane", seats_reserved: 3)
      john = attendee(shows(:past), "John", seats_reserved: 2)

      patch attendance_madmin_show_path(shows(:past)), params: { seats_used: { jane.id => "3", john.id => "-1" } }

      assert_response :unprocessable_content
      assert_select "input[name=?][value=?]", "seats_used[#{john.id}]", "-1"
      assert_select ".error", text: /greater than or equal to 0/
      assert_nil jane.reload.seats_used
      assert_nil john.reload.seats_used
    end

    test "update_attendance saves nothing when a seats used is left blank" do
      jane = attendee(shows(:past), "Jane", seats_reserved: 3)
      john = attendee(shows(:past), "John", seats_reserved: 2)

      patch attendance_madmin_show_path(shows(:past)), params: { seats_used: { jane.id => "3", john.id => "" } }

      assert_response :unprocessable_content
      assert_select ".alert-danger", text: I18n.t("madmin.shows.attendance.not_saved")
      assert_select ".error", text: I18n.t("madmin.shows.attendance.seats_used_blank"), count: 1
      assert_nil jane.reload.seats_used
    end

    test "update_attendance ignores a seats_used that isn't a list" do
      jane = attendee(shows(:past), "Jane", seats_reserved: 3)

      patch attendance_madmin_show_path(shows(:past)), params: { seats_used: "3" }

      assert_redirected_to attendance_madmin_show_path(shows(:past))
      assert_nil jane.reload.seats_used
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

      assert_enqueued_with(job: BatchRunFanOutJob, args: [ batch_run.id ]) do
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

      assert_enqueued_with(job: BatchRunFanOutJob, args: [ batch_run.id ]) do
        patch retry_failed_batch_run_madmin_show_path(show, batch_run_id: batch_run.id)
      end

      batch_run.reload
      assert batch_run.running?
      assert_nil batch_run.completed_at
      assert_redirected_to madmin_show_path(show)
      assert_match(/Retrying 1 failed invites/, flash[:notice])
    end

    test "retry_failed_batch_run refuses a show that has already happened" do
      show = shows(:past)
      person = Person.create!(first_name: "Retry", last_name: "Late", email: "retry-late@example.com", status: "active")
      batch_run = BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, failed_count: 1, completed_at: Time.current)
      batch_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")

      assert_no_enqueued_jobs(only: BatchRunFanOutJob) do
        patch retry_failed_batch_run_madmin_show_path(show, batch_run_id: batch_run.id)
      end

      assert_predicate batch_run.reload, :completed?
      assert_match(/already happened/, flash[:alert])
    end

    test "a past show's page shows its failed sends without a retry button" do
      show = shows(:past)
      person = Person.create!(first_name: "Past", last_name: "Failure", email: "past-failure@example.com", status: "active")
      batch_run = BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, failed_count: 1, completed_at: Time.current)
      batch_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")

      get madmin_show_path(show)

      assert_select ".batch-progress-status", text: /1 failed/
      assert_select "form[action^='#{retry_failed_batch_run_madmin_show_path(show)}']", count: 0
    end

    test "the batch buttons ask for confirmation and are wired to disable on submit" do
      get madmin_show_path(shows(:upcoming))

      assert_select "form[data-controller='disable-on-submit'][data-action='turbo:submit-start->disable-on-submit#disable']", minimum: 3
      [ "Send Invites", "Send to Unopened", "Send Reminders" ].each do |label|
        assert_select "button[data-disable-on-submit-target='submit'][data-turbo-confirm]", text: label
      end
    end

    test "the Send Invites confirmation says when invites already went out" do
      show = shows(:upcoming)
      BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, sent_count: 1, completed_at: Time.zone.parse("2026-09-20 12:00"))

      get madmin_show_path(show)

      assert_select "button[data-turbo-confirm*='already went out'][data-turbo-confirm*='September 20, 2026']", text: "Send Invites"
    end

    test "the Send Invites confirmation ignores an invite run that sent nothing" do
      show = shows(:upcoming)
      # e.g. cancelled before anything went out, or every send failed.
      BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 2, failed_count: 1, completed_at: Time.zone.parse("2026-09-20 12:00"))

      get madmin_show_path(show)

      assert_select "button[data-turbo-confirm='Send invites for #{show.name}?']", text: "Send Invites"
    end

    test "retry_failed_batch_run recovers an item stranded by a crash during an earlier retry attempt" do
      show = shows(:upcoming)
      person = Person.create!(first_name: "Retry", last_name: "Stranded", email: "retry-stranded-claim@example.com", status: "active")
      batch_run = BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, failed_count: 1, completed_at: Time.current)
      # Simulates a worker crashing between an earlier retry attempt
      # claiming this item (setting fan_out_enqueued_at) and actually
      # enqueueing a BatchRunItemJob for it -- unlike a "pending" item's
      # equivalent stranded claim, this one is never picked up
      # automatically by staleness alone (see BatchRunFanOutJob), so a
      # fresh admin retry click, which resets it unconditionally, is
      # what has to recover it.
      item = batch_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom", fan_out_enqueued_at: 1.day.ago)

      assert_enqueued_with(job: BatchRunItemJob, args: [ item.id ]) do
        perform_enqueued_jobs(only: BatchRunFanOutJob) do
          patch retry_failed_batch_run_madmin_show_path(show, batch_run_id: batch_run.id)
        end
      end
    end

    test "retry_failed_batch_run resets counted_at so the run doesn't look complete before the retries resolve" do
      show = shows(:upcoming)
      person_a = Person.create!(first_name: "Retry", last_name: "Aardvark", email: "retry-a@example.com", status: "active")
      person_b = Person.create!(first_name: "Retry", last_name: "Baboon", email: "retry-b@example.com", status: "active")
      batch_run = BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 2, failed_count: 2, completed_at: Time.current)
      item_a = batch_run.batch_run_items.create!(recipient: person_a, status: "failed", error_message: "boom", counted_at: 1.hour.ago)
      item_b = batch_run.batch_run_items.create!(recipient: person_b, status: "failed", error_message: "boom", counted_at: 1.hour.ago)

      patch retry_failed_batch_run_madmin_show_path(show, batch_run_id: batch_run.id)

      batch_run.reload
      assert batch_run.running?
      # Deliberately still "failed", not reset to "pending": if the
      # retry's own fan-out enqueue below had failed, that's what lets
      # the retry button/gate find these again on a later click.
      assert item_a.reload.failed?
      assert item_b.reload.failed?
      assert_nil item_a.counted_at, "counted_at must be reset so a still-outstanding retry doesn't look already-counted"
      assert_nil item_b.counted_at
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

      assert_enqueued_with(job: BatchRunFanOutJob, args: [ old_run.id ]) do
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

    test "retry_failed_batch_run does not reopen a run that was cancelled concurrently after being read" do
      show = shows(:upcoming)
      person = Person.create!(first_name: "Retry", last_name: "CancelledRace", email: "retry-cancelled-race@example.com", status: "active")
      batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 2, sent_count: 1)
      item = batch_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")

      # Simulates a concurrent cancel_batch_run completing the run
      # between this request's read of batch_run (at the top of the
      # action) and its later conditional write -- hooked onto #kind,
      # which the controller calls on its own freshly-loaded instance
      # early on, well before that write.
      triggered = false
      original_kind = BatchRun.instance_method(:kind)
      BatchRun.define_method(:kind) do
        unless triggered
          triggered = true
          BatchRun.where(id: id).update_all(status: BatchRun.statuses[:completed], completed_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
        end
        original_kind.bind(self).call
      end

      begin
        assert_no_enqueued_jobs do
          patch retry_failed_batch_run_madmin_show_path(show, batch_run_id: batch_run.id)
        end
      ensure
        BatchRun.define_method(:kind, original_kind)
      end

      assert_redirected_to madmin_show_path(show)
      assert_match(/status just changed/, flash[:alert])
      assert batch_run.reload.completed?, "the concurrent cancellation must win, not be silently overwritten back to running"
      assert item.reload.failed?, "the failed item must not have been touched by a retry that should have been rejected"
    end

    test "retry_failed_batch_run redirects with a friendly alert instead of a raw error when the retry fan-out job fails to enqueue" do
      show = shows(:upcoming)
      person = Person.create!(first_name: "Retry", last_name: "EnqueueFail", email: "retry-enqueue-fail@example.com", status: "active")
      batch_run = BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, failed_count: 1, completed_at: Time.current)
      batch_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")

      original_perform_later = BatchRunFanOutJob.method(:perform_later)
      BatchRunFanOutJob.define_singleton_method(:perform_later) do |*_args|
        raise SolidQueue::Job::EnqueueError, "transient boom"
      end

      begin
        patch retry_failed_batch_run_madmin_show_path(show, batch_run_id: batch_run.id)
      ensure
        BatchRunFanOutJob.define_singleton_method(:perform_later, original_perform_later)
      end

      assert_redirected_to madmin_show_path(show)
      assert_match(/try again/, flash[:alert])
      # The run itself is still correctly reopened -- the button/gate
      # will pick this back up on a later click since they query the
      # real failed items, not the (already-reset) counter.
      assert batch_run.reload.running?
    end

    test "cancel_batch_run completes a running batch, cancelling its still-pending items but keeping resolved ones" do
      show = shows(:upcoming)
      sent_person = Person.create!(first_name: "Already", last_name: "Sent", email: "cancel-sent@example.com", status: "active")
      pending_person = Person.create!(first_name: "Still", last_name: "Pending", email: "cancel-pending@example.com", status: "active")
      batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 2, sent_count: 1)
      sent_item = batch_run.batch_run_items.create!(recipient: sent_person, status: "sent", sent_at: Time.current)
      pending_item = batch_run.batch_run_items.create!(recipient: pending_person, status: "pending")

      patch cancel_batch_run_madmin_show_path(show, batch_run_id: batch_run.id)

      assert_redirected_to madmin_show_path(show)
      assert_match(/Cancelled/, flash[:notice])
      batch_run.reload
      assert batch_run.completed?
      assert_not_nil batch_run.completed_at
      assert sent_item.reload.sent?, "an already-resolved item's outcome must not be touched by cancelling"
      assert pending_item.reload.cancelled?
    end

    test "cancel_batch_run broadcasts the completed state, so another admin's open tab updates without a refresh" do
      show = shows(:upcoming)
      batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1)

      assert_turbo_stream_broadcasts [ show, :batch_progress ] do
        patch cancel_batch_run_madmin_show_path(show, batch_run_id: batch_run.id)
      end
    end

    test "cancel_batch_run redirects with an alert when there is nothing in progress to cancel" do
      show = shows(:upcoming)
      batch_run = BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, sent_count: 1)

      patch cancel_batch_run_madmin_show_path(show, batch_run_id: batch_run.id)

      assert_redirected_to madmin_show_path(show)
      assert_match(/no in-progress/, flash[:alert])
    end

    test "cancel_batch_run redirects with an alert for a batch_run_id that doesn't belong to this show" do
      show = shows(:upcoming)
      other_show_batch_run = BatchRun.create!(show: shows(:sold_out), kind: "invite", status: "running", total_count: 1)

      patch cancel_batch_run_madmin_show_path(show, batch_run_id: other_show_batch_run.id)

      assert_redirected_to madmin_show_path(show)
      assert_match(/no in-progress/, flash[:alert])
      assert other_show_batch_run.reload.running?
    end

    test "cancelling frees active_kind_lock so a fresh batch of the same kind can start" do
      show = shows(:upcoming)
      batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1)

      patch cancel_batch_run_madmin_show_path(show, batch_run_id: batch_run.id)
      assert batch_run.reload.completed?

      assert_difference("BatchRun.count", 1) do
        patch send_invites_madmin_show_path(show)
      end
    end

    test "a job already enqueued for a since-cancelled pending item does not send it or corrupt the run's counters" do
      show = shows(:upcoming)
      person = Person.create!(first_name: "Cancelled", last_name: "Underneath", email: "cancel-stray-job@example.com", status: "active")
      batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1)
      item = batch_run.batch_run_items.create!(recipient: person, status: "pending", fan_out_enqueued_at: Time.current)

      patch cancel_batch_run_madmin_show_path(show, batch_run_id: batch_run.id)
      assert item.reload.cancelled?

      assert_no_emails do
        BatchRunItemJob.perform_now(item.id)
      end

      batch_run.reload
      assert_equal 0, batch_run.sent_count
      assert_equal 0, batch_run.failed_count
      assert batch_run.completed?, "the run must stay completed, not be reopened by a stray job for a cancelled item"
    end

    test "show page shows a cancel button for a batch run in progress, but not once it's completed" do
      show = shows(:upcoming)
      batch_run = BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1)

      get madmin_show_path(show)
      assert_select "#batch_run_progress_invite button", text: "Cancel", count: 1

      batch_run.update!(status: :completed, completed_at: Time.current, sent_count: 1)
      get madmin_show_path(show)
      assert_select "#batch_run_progress_invite button", text: "Cancel", count: 0
    end

    test "the show page subscribes to one stable stream regardless of which batch run is active" do
      show = shows(:upcoming)
      BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, sent_count: 1)
      get madmin_show_path(show)
      first_stream_names = response.body.scan(/signed-stream-name="([^"]+)"/).flatten

      BatchRun.create!(show: show, kind: "invite", status: "running", total_count: 1)
      get madmin_show_path(show)
      second_stream_names = response.body.scan(/signed-stream-name="([^"]+)"/).flatten

      expected_stream_name = Turbo::StreamsChannel.signed_stream_name([ show, :batch_progress ])
      assert_equal [ expected_stream_name ], first_stream_names
      assert_equal first_stream_names, second_stream_names, "the subscription must stay the same across batch runs, not change to a new per-run stream"
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

    test "the next show subscribes to batch progress even before any batch run exists" do
      show = shows(:upcoming)
      assert_not show.batch_runs.exists?

      get madmin_show_path(show)

      assert_response :success
      assert_select ".batch-progress", count: 1
      stream_names = response.body.scan(/signed-stream-name="([^"]+)"/).flatten
      assert_includes stream_names, Turbo::StreamsChannel.signed_stream_name([ show, :batch_progress ])
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

    test "batch progress displays a retried older run, not a newer completed run of the same kind" do
      show = shows(:upcoming)
      person = Person.create!(first_name: "Retry", last_name: "Reopen", email: "retry-reopen@example.com", status: "active")
      old_run = BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, failed_count: 1, completed_at: 1.day.ago)
      old_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")
      BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, sent_count: 1, completed_at: Time.current)

      patch retry_failed_batch_run_madmin_show_path(show, batch_run_id: old_run.id)
      assert old_run.reload.running?

      get madmin_show_path(show)

      assert_response :success
      assert_select "#batch_run_progress_invite", text: %r{0/1 sent, 1 failed}

      stream_names = response.body.scan(/signed-stream-name="([^"]+)"/).flatten
      assert_includes stream_names, Turbo::StreamsChannel.signed_stream_name([ show, :batch_progress ])
    end

    private

      def attendee(show, first_name, seats_reserved: 2, **attrs)
        RSVP.create!(show:, first_name:, last_name: "Smith", email: "#{first_name.downcase}.smith@example.com",
                     response: "yes", confirmed: "confirmed", seats_reserved:, **attrs)
      end

      # The print view's row for an attendee, as its <td> cells.
      def attendee_row_cells(full_name)
        row = response.parsed_body.css("tbody tr").find { |tr| tr.text.include?(full_name) }
        assert row, "no attendee row found for #{full_name}"
        row.css("td")
      end
  end
end

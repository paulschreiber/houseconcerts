require "test_helper"

module Madmin
  class DashboardControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in admins(:one)
    end

    test "shows the next show, its unconfirmed RSVPs, and the previous show's work to do" do
      unconfirmed = rsvp(shows(:upcoming), "Jane")
      rsvp(shows(:past), "John", confirmed: "confirmed", phone_number: "2125551234")
      Person.create!(first_name: "Joan", last_name: "Smith", email: "joan.smith@example.com", status: "removed")
      opener = Person.create!(first_name: "Pat", last_name: "Lee", email: "pat.lee@example.com")
      Open.create!(tag: "#{shows(:upcoming).slug}:invite", email: opener.email, open: true)

      get madmin_root_path

      assert_response :success
      assert_select "h2", text: "Next show: #{shows(:upcoming).name}"
      assert_select "form[action=?] button", confirm_madmin_rsvp_path(unconfirmed), text: "Confirm"
      assert_select "h2", text: "Previous show: #{shows(:past).name}"
      assert_select "p", text: "Attendance isn’t recorded yet"
      assert_select "form[action=?] button", add_nonsubscribers_madmin_show_path(shows(:past)), text: "Add to mailing list"
      assert_select "td", text: "joan.smith@example.com"
      assert_select "td a[href=?]", madmin_person_path(opener), text: "Pat Lee"
      assert_select "td", text: "pat.lee@example.com", count: 0
      assert_select "td abbr.show-initials[title=?]", shows(:upcoming).name
      assert_select "svg path", minimum: 2
    end

    test "lists waitlisted RSVPs with the unconfirmed ones, and leaves their seats out of the total" do
      rsvp(shows(:upcoming), "Jane", confirmed: "waitlisted", seats_reserved: 4)

      get madmin_root_path

      assert_select "td", text: /Jane Smith\s+Waitlisted/
      assert_select ".metric", text: /Seats\s+2\s+2 confirmed · 0 unconfirmed/
      assert_select ".metric", text: /Waitlisted\s+4/
    end

    test "shows seats with a yes response in the recent RSVPs" do
      rsvp(shows(:upcoming), "Jane", seats_reserved: 3)
      rsvp(shows(:upcoming), "John", response: "no", seats_reserved: 0)

      get madmin_root_path

      assert_select "td", text: "Yes (3)"
      assert_select "td", text: "No"
    end

    test "says when there's nothing to do for the previous show" do
      rsvp(shows(:past), "John", confirmed: "confirmed", seats_used: 2)
      Person.create!(first_name: "John", last_name: "Smith", email: "john.smith@example.com")

      get madmin_root_path

      assert_select "p", text: "✓ Attendance recorded"
      assert_select "p", text: "✓ Everyone who RSVPd is on the mailing list"
      assert_select "p", text: "✓ No phone numbers to add"
    end

    test "renders without any shows" do
      Show.destroy_all

      get madmin_root_path

      assert_response :success
      assert_select "p", text: /No upcoming confirmed show/
      assert_select "p", text: "No shows have happened yet."
      assert_select ".graph", count: 0
    end

    test "shows no warning when there are no failed batch items" do
      get madmin_root_path

      assert_response :success
      assert_select ".dashboard-warning", count: 0
    end

    test "shows a warning linking to the show when a batch item has failed" do
      show = shows(:upcoming)
      batch_run = BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, failed_count: 1)
      person = Person.create!(first_name: "Failed", last_name: "Invite", email: "dashboard.failed@example.com", status: "active")
      batch_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")

      get madmin_root_path

      assert_response :success
      assert_select ".dashboard-warning" do
        assert_select "a[href=?]", madmin_show_path(show), text: show.name
        assert_select "li", text: /1 failed send/
      end
    end

    test "groups multiple failed items for the same show into a single count" do
      show = shows(:upcoming)
      batch_run = BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 2, failed_count: 2)
      2.times do |i|
        person = Person.create!(first_name: "Failed", last_name: "Invite#{i}", email: "dashboard.failed.#{i}@example.com", status: "active")
        batch_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")
      end

      get madmin_root_path

      assert_response :success
      assert_select ".dashboard-warning li", text: /2 failed sends/
    end

    test "surfaces the distinct error messages for a show's failed items" do
      show = shows(:upcoming)
      batch_run = BatchRun.create!(show: show, kind: "remind", status: "completed", total_count: 3, failed_count: 3)
      3.times do |i|
        rsvp = RSVP.create!(show: show, email: "dashboard.reason.#{i}@example.com", first_name: "Failed", last_name: "Reminder#{i}",
                            response: "yes", confirmed: "confirmed", seats_reserved: 1)
        batch_run.batch_run_items.create!(recipient: rsvp, status: "failed", error_message: "Twilio credentials invalid")
      end

      get madmin_root_path

      assert_response :success
      assert_select ".dashboard-warning-reasons li", text: "Twilio credentials invalid", count: 1
    end

    test "the warning disappears once the failed item is corrected" do
      show = shows(:upcoming)
      batch_run = BatchRun.create!(show: show, kind: "invite", status: "completed", total_count: 1, failed_count: 1)
      person = Person.create!(first_name: "Failed", last_name: "Invite", email: "dashboard.corrected@example.com", status: "active")
      item = batch_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")

      get madmin_root_path
      assert_select ".dashboard-warning", count: 1

      item.update!(status: :sent, error_message: nil, sent_at: Time.current)

      get madmin_root_path
      assert_select ".dashboard-warning", count: 0
    end

    test "doesn't list failed sends for shows that have already happened" do
      batch_run = BatchRun.create!(show: shows(:past), kind: "invite", status: "completed", total_count: 1, failed_count: 1)
      person = Person.create!(first_name: "Past", last_name: "Send", email: "dashboard.past@example.com", status: "active")
      batch_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")

      get madmin_root_path

      assert_select ".dashboard-warning", count: 0
    end

    test "the retry button is wired to disable on submit" do
      batch_run = BatchRun.create!(show: shows(:upcoming), kind: "invite", status: "completed", total_count: 1, failed_count: 1)
      person = Person.create!(first_name: "Retry", last_name: "Button", email: "dashboard.retry@example.com", status: "active")
      batch_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")

      get madmin_root_path

      assert_select "form[data-controller='disable-on-submit'] button[data-disable-on-submit-target='submit']", text: "Retry"
    end

    private

      def rsvp(show, first_name, **attrs)
        RSVP.create!(show:, first_name:, last_name: "Smith", email: "#{first_name.downcase}.smith@example.com",
                     response: "yes", seats_reserved: 2, **attrs)
      end
  end
end

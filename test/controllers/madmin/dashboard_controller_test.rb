require "test_helper"

module Madmin
  class DashboardControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in admins(:one)
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
                            response: "yes", confirmed: "yes", seats_reserved: 1)
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
  end
end

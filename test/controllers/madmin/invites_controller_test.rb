require "test_helper"

module Madmin
  class InvitesControllerTest < ActionDispatch::IntegrationTest
    include BatchTestHelpers

    setup do
      sign_in admins(:one)
    end

    test "index lists every show's revisions, newest first, linking to each revision's page" do
      upcoming = invite_messages(:upcoming)
      create_run(status: "completed", sent_count: 1)
      past = travel_to(1.day.from_now) { shows(:past).invite_messages.create!(intro: "Past", about: "Past") }

      get madmin_invite_messages_path

      assert_response :success
      assert_select "h1", text: "Invites"
      headings = css_select("thead th").map { |cell| cell.text.squish }
      assert_equal [ "Show", "Revision", "Status", "Saved", "" ], headings
      rows = css_select("tbody tr").map { |row| row.css("td").map { |cell| cell.text.squish } }
      assert_equal [ shows(:past).dated_name, "1", "Not sent" ], rows[0].first(3)
      assert_equal [ show.dated_name, "1", "Sent" ], rows[1].first(3)
      assert_select "td a[href=?]", madmin_show_invite_message_path(shows(:past), past), text: shows(:past).dated_name
      assert_select "td a[href=?]", madmin_show_invite_message_path(show, upcoming), text: show.dated_name
      assert_select "td a", text: "1", count: 0
    end

    test "index has Edit only for unsent revisions, and no New" do
      create_run(status: "completed", sent_count: 1)
      second = show.invite_messages.create!(intro: "Second", about: "Second")

      get madmin_invite_messages_path

      assert_select "td.actions a.btn-secondary[href=?]", edit_madmin_show_invite_message_path(show, second), text: "Edit"
      assert_select "td.actions a[href=?]", edit_madmin_show_invite_message_path(show, invite_messages(:upcoming)), count: 0
      assert_select "a", text: /\ANew/, count: 0
    end

    test "the sidebar links to Invites" do
      get madmin_invite_messages_path

      assert_select "nav a[href=?]", madmin_invite_messages_path, text: "Invites"
    end

    test "index requires signing in" do
      sign_out :admin

      get madmin_invite_messages_path

      assert_redirected_to new_admin_session_path
    end
  end
end

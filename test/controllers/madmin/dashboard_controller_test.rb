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
      assert_select "svg path", minimum: 2
    end

    test "lists waitlisted RSVPs with the unconfirmed ones, and leaves their seats out of the total" do
      rsvp(shows(:upcoming), "Jane", confirmed: "waitlisted", seats_reserved: 4)

      get madmin_root_path

      assert_select "td", text: /Jane Smith\s+Waitlisted/
      assert_select ".metric", text: /Seats\s+2\s+2 confirmed · 0 unconfirmed/
      assert_select ".metric", text: /Waitlisted\s+4/
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

    private

      def rsvp(show, first_name, **attrs)
        RSVP.create!(show:, first_name:, last_name: "Smith", email: "#{first_name.downcase}.smith@example.com",
                     response: "yes", seats_reserved: 2, **attrs)
      end
  end
end

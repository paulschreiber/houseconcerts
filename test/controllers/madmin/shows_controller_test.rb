require "test_helper"

module Madmin
  class ShowsControllerTest < ActionDispatch::IntegrationTest
    include ActionMailer::TestHelper

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

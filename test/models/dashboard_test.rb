require "test_helper"

class DashboardTest < ActiveSupport::TestCase
  setup do
    @dashboard = Dashboard.new
  end

  test "next_show_seats and next_show_responses group the next show's RSVPs" do
    rsvp(shows(:upcoming), "Jane", seats_reserved: 3)
    rsvp(shows(:upcoming), "John", seats_reserved: 1, confirmed: "waitlisted")
    rsvp(shows(:upcoming), "Joan", response: "no")

    assert_equal({ "confirmed" => 2, "unconfirmed" => 3, "waitlisted" => 1 }, @dashboard.next_show_seats)
    assert_equal({ "yes" => 3, "no" => 1 }, @dashboard.next_show_responses)
  end

  test "unconfirmed_rsvps are the next show's unconfirmed and waitlisted yes RSVPs, oldest first" do
    newer = rsvp(shows(:upcoming), "Jane", created_at: 1.hour.ago)
    older = rsvp(shows(:upcoming), "John", created_at: 1.day.ago)
    waitlisted = rsvp(shows(:upcoming), "Joan", confirmed: "waitlisted")
    rsvp(shows(:past), "Jill")

    assert_equal [ older, newer, waitlisted ], @dashboard.unconfirmed_rsvps.to_a
  end

  test "seats_by_show leaves out waitlisted seats" do
    rsvp(shows(:upcoming), "Jane", seats_reserved: 3)
    rsvp(shows(:upcoming), "John", seats_reserved: 4, confirmed: "waitlisted")

    assert_equal 5, @dashboard.seats_by_show([ shows(:upcoming) ])[shows(:upcoming).id]
  end

  test "upcoming_shows includes unconfirmed shows, but not cancelled or past ones" do
    unconfirmed = shows(:upcoming).dup.tap { |show| show.update!(slug: nil, name: "Unconfirmed Show", status: "unconfirmed") }
    shows(:sold_out).update!(status: "cancelled")

    assert_includes @dashboard.upcoming_shows, unconfirmed
    assert_includes @dashboard.upcoming_shows, shows(:upcoming)
    assert_not_includes @dashboard.upcoming_shows, shows(:sold_out)
    assert_not_includes @dashboard.upcoming_shows, shows(:past)
  end

  test "attendance_recorded? once every previous-show attendee has seats used" do
    assert_not @dashboard.attendance_recorded?, "no attendees"

    jane = rsvp(shows(:past), "Jane", confirmed: "confirmed")
    rsvp(shows(:past), "John", confirmed: "confirmed", seats_used: 1)
    assert_not @dashboard.attendance_recorded?

    jane.update!(seats_used: 0)
    assert_predicate @dashboard, :attendance_recorded?
  end

  test "nonsubscribers_to_add counts the previous show's RSVPs with no Person" do
    rsvp(shows(:past), "Jane")
    Person.create!(first_name: "John", last_name: "Smith", email: "john.smith@example.com", status: "removed")
    rsvp(shows(:past), "John")

    assert_equal 1, @dashboard.nonsubscribers_to_add
  end

  test "phone_numbers_to_add counts people missing a phone number the previous show's RSVPs have" do
    rsvp(shows(:past), "Jane", phone_number: "2125551234")
    Person.create!(first_name: "Jane", last_name: "Smith", email: "jane.smith@example.com")

    assert_equal 1, @dashboard.phone_numbers_to_add
  end

  test "phone_numbers_to_add is zero when no show has happened" do
    rsvp(shows(:upcoming), "Jane", phone_number: "2125551234")
    Person.create!(first_name: "Jane", last_name: "Smith", email: "jane.smith@example.com")
    shows(:past).destroy!

    assert_equal 0, Dashboard.new.phone_numbers_to_add
  end

  test "openers_by_email finds each email's Person, or else its latest RSVP" do
    person = Person.create!(first_name: "Jane", last_name: "Smith", email: "jane.smith@example.com")
    rsvp(shows(:past), "John")
    latest = rsvp(shows(:upcoming), "John")
    opens = %w[jane.smith@example.com john.smith@example.com nobody@example.com].map { |email| Open.new(email:) }

    assert_equal({ "jane.smith@example.com" => person, "john.smith@example.com" => latest }, @dashboard.openers_by_email(opens))
  end

  test "graph_series has cumulative seats per day from a past show's first yes RSVP to show day" do
    show_day = shows(:past).start
    rsvp(shows(:past), "Jane", seats_reserved: 2, created_at: show_day - 10.days)
    rsvp(shows(:past), "John", seats_reserved: 3, created_at: show_day - 3.days)
    rsvp(shows(:past), "Joan", response: "no", created_at: show_day - 5.days)
    rsvp(shows(:past), "Jill", confirmed: "waitlisted", created_at: show_day - 2.days)

    series = @dashboard.graph_series.find { |s| s.show == shows(:past) }

    assert_not series.next_show
    assert_equal (0..10).to_a.reverse, series.points.map(&:first)
    assert_equal [ 10, 2 ], series.points.first
    assert_equal([ 3, 5 ], series.points.find { |days_before, _| days_before == 3 })
    assert_equal [ 0, 5 ], series.points.last
  end

  test "graph_series ends the next show's line today" do
    series = @dashboard.graph_series.find { |s| s.show == shows(:upcoming) }
    days_left = (shows(:upcoming).start.to_date - Time.zone.today).to_i

    assert series.next_show
    assert_equal [ [ days_left, 2 ] ], series.points
  end

  test "graph_series skips shows without yes RSVPs" do
    assert_not_includes @dashboard.graph_series.map(&:show), shows(:past)
  end

  private

    def rsvp(show, first_name, seats_reserved: 2, **attrs)
      RSVP.create!(show:, first_name:, last_name: "Smith", email: "#{first_name.downcase}.smith@example.com",
                   response: "yes", seats_reserved:, **attrs)
    end
end

require "test_helper"

class ShowTest < ActiveSupport::TestCase
  test "fixture is valid" do
    assert shows(:upcoming).valid?
    assert shows(:past).valid?
  end

  test "upcoming scope includes only shows that haven't happened yet" do
    assert_includes Show.upcoming, shows(:upcoming)
    assert_not_includes Show.upcoming, shows(:past)
  end

  test "past/occurred scope includes only shows that already happened" do
    assert_includes Show.past, shows(:past)
    assert_not_includes Show.past, shows(:upcoming)
  end

  test "occurred? reflects whether the show's start is in the past" do
    assert shows(:past).occurred?
    assert_not shows(:upcoming).occurred?
  end

  test "status predicate methods reflect the status attribute" do
    show = Show.new(status: "confirmed")
    assert show.confirmed?
    assert_not show.cancelled?

    show.status = "cancelled"
    assert show.cancelled?
    assert_not show.confirmed?
  end

  test "set_end_time fills in end based on show_duration when blank" do
    show = Show.new(
      name: "Duration Test",
      venue: venues(:one),
      start: 1.month.from_now,
      status: "confirmed",
      price: 20
    )
    show.valid?

    assert_equal Settings.show_duration.hours, show.end - show.start
  end

  test "requires end to be after start" do
    show = Show.new(
      name: "Invalid Show",
      venue: venues(:one),
      start: 1.month.from_now,
      end: 1.month.from_now - 1.hour,
      status: "confirmed",
      price: 20
    )
    assert_not show.valid?
    assert_includes show.errors.attribute_names, :end
  end

  test "duration returns the length of the show in seconds" do
    assert_equal 2.hours.to_i, shows(:upcoming).duration
  end

  test "self.next and self.previous return the nearest upcoming/past show" do
    assert_equal shows(:upcoming), Show.next
    assert_equal shows(:past), Show.previous
  end

  test "attendees returns confirmed yes rsvps" do
    assert_includes shows(:upcoming).attendees, rsvps(:one)
  end
end

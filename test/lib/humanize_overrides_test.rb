require "test_helper"

class HumanizeOverridesTest < ActiveSupport::TestCase
  test "humanizes the unconfirmed_rsvps scope name with the RSVPs acronym capitalized" do
    assert_equal "Unconfirmed RSVPs", RSVP::UNCONFIRMED_RSVPS_SCOPE.humanize
  end

  test "leaves humanize behavior for other strings unchanged" do
    assert_equal "Next show attendees", "next_show_attendees".humanize
    assert_equal "Employee salary", "employee_salary".humanize
  end
end

require "test_helper"

class PrevShowRakeTest < ActiveSupport::TestCase
  setup do
    load_rake_tasks
    Rake::Task["prev_show:attendees"].reenable
  end

  test "attendees lists confirmed attendees of the previous show" do
    rsvp = rsvps(:one)
    rsvp.update!(show: shows(:past))

    out, = capture_io { Rake::Task["prev_show:attendees"].invoke }

    assert_includes out, rsvp.email_address_with_name
    assert_includes out, "Total: 2 seats / 1 reservations"
  end
end

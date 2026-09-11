require "test_helper"

class RSVPNoTest < ActiveSupport::TestCase
  test "creates a new no RSVP for the person and show" do
    person = people(:one)
    show = shows(:upcoming)

    assert_difference "RSVP.count", 1 do
      RSVPNo.call(person, show)
    end

    rsvp = RSVP.find_by(email: person.email, show: show)
    assert rsvp.no?
  end

  test "flips an existing RSVP to no" do
    person = people(:one)
    show = shows(:upcoming)
    rsvp = RSVP.create!(first_name: person.first_name, last_name: person.last_name, email: person.email,
                        show: show, response: "yes", seats_reserved: 2)

    assert_no_difference "RSVP.count" do
      RSVPNo.call(person, show)
    end

    assert rsvp.reload.no?
  end
end

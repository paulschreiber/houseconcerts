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

  test "recovers when a concurrent request wins the race for the same person and show" do
    person = people(:one)
    show = shows(:upcoming)

    # Simulate two requests that both miss the find_or_initialize_by above:
    # the first call to #save creates the "winning" row out from under us and
    # raises the DB's unique-index violation, exactly like a concurrent
    # request would; the second call (our recovery update) behaves normally.
    original_save = RSVP.instance_method(:save)
    raced = false
    RSVP.send(:define_method, :save) do |*args, **kwargs|
      if raced
        original_save.bind_call(self, *args, **kwargs)
      else
        raced = true
        RSVP.create!(show_id: show.id, email: person.email, first_name: "Winner", last_name: "Row",
                     response: "yes", seats_reserved: 2)
        raise ActiveRecord::RecordNotUnique, "Duplicate entry for key 'index_rsvps_on_show_id_and_email'"
      end
    end

    begin
      assert_difference "RSVP.count", 1 do
        assert RSVPNo.call(person, show)
      end
    ensure
      RSVP.send(:define_method, :save, original_save)
    end

    assert_equal 1, RSVP.where(show_id: show.id, email: person.email).count
    assert RSVP.find_by(show_id: show.id, email: person.email).no?
  end
end

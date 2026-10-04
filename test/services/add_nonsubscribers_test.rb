require "test_helper"

class AddNonsubscribersTest < ActiveSupport::TestCase
  test "adds the show's yes RSVPs who aren't on the mailing list" do
    rsvp = yes_rsvp("Jane", "Smith")

    result = nil
    assert_difference("Person.count", 1) { result = AddNonsubscribers.call(shows(:past)) }

    assert_equal [ rsvp ], result.added
    assert_empty result.skipped
    assert_predicate Person.find_by(email: rsvp.email), :active?
  end

  test "doesn't re-add someone who unsubscribed" do
    Person.create!(first_name: "Jane", last_name: "Smith", email: "jane.smith@example.com", status: "removed")
    rsvp = yes_rsvp("Jane", "Smith")

    result = nil
    assert_no_difference("Person.count") { result = AddNonsubscribers.call(shows(:past)) }

    assert_empty result.added
    assert_equal [ rsvp ], result.skipped
    assert_predicate Person.find_by(email: rsvp.email), :removed?
  end

  test "ignores no RSVPs and other shows" do
    yes_rsvp("Jane", "Smith", show: shows(:upcoming))
    RSVP.create!(show: shows(:past), first_name: "John", last_name: "Smith", email: "john.smith@example.com", response: "no")

    result = AddNonsubscribers.call(shows(:past))

    assert_empty result.added
    assert_empty result.skipped
  end

  test "reports a person who couldn't be saved instead of calling them skipped" do
    rsvp = yes_rsvp("Jane", "Smith")
    rsvp.update_column(:first_name, "J") # rubocop:disable Rails/SkipsModelValidations

    result = nil
    assert_no_difference("Person.count") { result = AddNonsubscribers.call(shows(:past)) }

    assert_empty result.added
    assert_empty result.skipped
    assert_equal [ rsvp ], result.failed.keys
    assert_predicate result.failed[rsvp], :present?
  end

  test "someone added by another run in the meantime is left out, not an error" do
    yes_rsvp("Jane", "Smith")
    original = RSVP.instance_method(:create_person)
    RSVP.define_method(:create_person) { raise ActiveRecord::RecordNotUnique, "Duplicate entry" }

    result = AddNonsubscribers.call(shows(:past))

    assert_empty result.added
    assert_empty result.skipped
    assert_empty result.failed
  ensure
    RSVP.define_method(:create_person, original)
  end

  private

    def yes_rsvp(first_name, last_name, show: shows(:past))
      RSVP.create!(show:, first_name:, last_name:, email: "#{first_name}.#{last_name}@example.com".downcase,
                   response: "yes", seats_reserved: 1)
    end
end

require "test_helper"

class PersonVenueGroupTest < ActiveSupport::TestCase
  test "rejects a duplicate person/venue_group pairing" do
    person = people(:one)
    venue_group = venue_groups(:one)
    PersonVenueGroup.create!(person: person, venue_group: venue_group)

    duplicate = PersonVenueGroup.new(person: person, venue_group: venue_group)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:person_id], "has already been taken"
  end

  test "allows the same person in a different venue group" do
    person = people(:one)
    PersonVenueGroup.create!(person: person, venue_group: venue_groups(:one))

    assert PersonVenueGroup.new(person: person, venue_group: venue_groups(:two)).valid?
  end
end

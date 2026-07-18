require "test_helper"

class VenueGroupTest < ActiveSupport::TestCase
  test "fixtures are valid" do
    assert venue_groups(:one).valid?
    assert venue_groups(:two).valid?
  end

  test "requires a name" do
    venue_group = VenueGroup.new(name: "")
    assert_not venue_group.valid?
    assert_includes venue_group.errors.attribute_names, :name
  end

  test "adding a venue creates the join record" do
    venue_group = venue_groups(:one)

    assert_difference("VenueGroupVenue.count", 1) do
      venue_group.venues << venues(:one)
    end
    assert_includes venue_group.venues, venues(:one)
  end

  test "adding a person creates the join record" do
    venue_group = venue_groups(:one)

    assert_difference("PersonVenueGroup.count", 1) do
      venue_group.people << people(:one)
    end
    assert_includes venue_group.people, people(:one)
  end

  test "destroying a venue group destroys its join records" do
    venue_group = venue_groups(:one)
    venue_group.venues << venues(:one)
    venue_group.people << people(:one)

    assert_difference([ "VenueGroupVenue.count", "PersonVenueGroup.count" ], -1) do
      venue_group.destroy
    end
  end
end

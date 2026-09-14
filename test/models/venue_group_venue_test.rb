require "test_helper"

class VenueGroupVenueTest < ActiveSupport::TestCase
  test "rejects a duplicate venue_group/venue pairing" do
    venue_group = venue_groups(:one)
    venue = venues(:one)
    VenueGroupVenue.create!(venue_group: venue_group, venue: venue)

    duplicate = VenueGroupVenue.new(venue_group: venue_group, venue: venue)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:venue_group_id], "has already been taken"
  end

  test "allows the same venue group on a different venue" do
    venue_group = venue_groups(:one)
    VenueGroupVenue.create!(venue_group: venue_group, venue: venues(:one))
    other_venue = Venue.create!(name: "Other Venue", address: "456 Elm St", city: "Brooklyn",
                                province: "NY", postcode: "11201", country: "US", capacity: 30)

    assert VenueGroupVenue.new(venue_group: venue_group, venue: other_venue).valid?
  end
end

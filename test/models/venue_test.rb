require "test_helper"

class VenueTest < ActiveSupport::TestCase
  test "fixture is valid" do
    assert venues(:one).valid?
  end

  test "requires name, address, and city" do
    venue = Venue.new(venues(:one).attributes.except("id").merge("name" => "", "address" => "", "city" => ""))
    assert_not venue.valid?
    assert_includes venue.errors.attribute_names, :name
    assert_includes venue.errors.attribute_names, :address
    assert_includes venue.errors.attribute_names, :city
  end

  test "requires a valid province code" do
    venue = Venue.new(venues(:one).attributes.except("id").merge("province" => "ZZ"))
    assert_not venue.valid?
    assert_includes venue.errors.attribute_names, :province
  end

  test "requires capacity within the configured range" do
    venue = Venue.new(venues(:one).attributes.except("id").merge("capacity" => Settings.venue.max_capacity + 1))
    assert_not venue.valid?
    assert_includes venue.errors.attribute_names, :capacity
  end

  test "upcase_province_and_country upcases before save" do
    venue = Venue.create!(venues(:one).attributes.except("id", "slug").merge("province" => "ny", "country" => "us"))
    assert_equal "NY", venue.province
    assert_equal "US", venue.country
  end

  test "full_address includes street, city, province name, and postcode" do
    address = venues(:one).full_address
    assert_includes address, venues(:one).address
    assert_includes address, venues(:one).city
    assert_includes address, venues(:one).postcode
  end

  test "location combines city and province name" do
    assert_equal "Brooklyn, New York", venues(:one).location
  end
end

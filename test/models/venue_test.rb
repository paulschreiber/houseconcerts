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

  test "formatted_directions renders markdown formatting" do
    venue = venues(:one)
    venue.directions = "Take the **B61** bus to *5th Ave*."

    assert_includes venue.formatted_directions, "<strong>B61</strong>"
    assert_includes venue.formatted_directions, "<em>5th Ave</em>"
  end

  test "formatted_directions escapes raw html instead of rendering it" do
    venue = venues(:one)
    venue.directions = "Ring the buzzer. <script>alert('xss')</script>"

    assert_not_includes venue.formatted_directions, "<script>"
    assert_includes venue.formatted_directions, "&lt;script&gt;"
  end

  test "formatted_contact_info escapes raw html instead of rendering it" do
    venue = venues(:one)
    venue.contact_info = "<img src=x onerror=alert(1)>"

    assert_not_includes venue.formatted_contact_info, "<img"
    assert_includes venue.formatted_contact_info, "&lt;img"
  end

  test "formatted_directions keeps http, https, and mailto links" do
    venue = venues(:one)
    venue.directions = "[Map](https://maps.example.com), [site](http://example.com), [email](mailto:host@example.com)"

    assert_includes venue.formatted_directions, %(<a href="https://maps.example.com">Map</a>)
    assert_includes venue.formatted_directions, %(<a href="http://example.com">site</a>)
    assert_includes venue.formatted_directions, %(<a href="mailto:host@example.com">email</a>)
  end

  test "formatted_directions and formatted_contact_info don't turn javascript: links into anchors" do
    venue = venues(:one)
    venue.directions = "[click me](javascript:alert(document.cookie))"
    venue.contact_info = "[call](JavaScript:alert(1))"

    [ venue.formatted_directions, venue.formatted_contact_info ].each do |html|
      assert_not_includes html, "<a"
      assert_not_includes html, "href"
    end
  end

  test "formatted_contact_info links tel: phone numbers" do
    venue = venues(:one)
    venue.contact_info = "[Call the host](tel:+1-555-0100), or [(555) 0101](tel:(555)0101)"

    assert_includes venue.formatted_contact_info, %(<a href="tel:+1-555-0100">Call the host</a>)
    assert_includes venue.formatted_contact_info, %(<a href="tel:(555)0101">(555) 0101</a>)
  end

  test "formatted_directions keeps relative links, titles, and formatted link text" do
    venue = venues(:one)
    venue.directions = %([Parking](/parking "Where to park"), [below](#entrance), [*map*](https://maps.example.com))

    assert_includes venue.formatted_directions, %(<a href="/parking" title="Where to park">Parking</a>)
    assert_includes venue.formatted_directions, %(<a href="#entrance">below</a>)
    assert_includes venue.formatted_directions, %(<a href="https://maps.example.com"><em>map</em></a>)
  end

  test "formatted_directions escapes link attributes" do
    venue = venues(:one)
    venue.directions = %([x](https://example.com/?a=1&b=2 "say "hi" <b>"))

    assert_includes venue.formatted_directions, %(href="https://example.com/?a=1&amp;b=2")
    assert_includes venue.formatted_directions, %(title="say &quot;hi&quot; &lt;b&gt;")
  end

  test "formatted_directions doesn't link other schemes or protocol-relative URLs" do
    venue = venues(:one)

    [ "data:text/html,<b>x</b>", "vbscript:msgbox(1)", "//evil.example/x", "tel:javascript:alert(1)", " javascript:alert(1)" ].each do |url|
      venue.directions = "[click](#{url})"

      assert_not_includes venue.formatted_directions, "<a", "#{url} should not become a link"
    end
  end
end

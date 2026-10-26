require "test_helper"

class JsonLdHelperTest < ActionView::TestCase
  test "ld_json_tag adds the schema.org context to the data" do
    script = Nokogiri::HTML.fragment(ld_json_tag("@type": "Thing", name: "Jane Smith")).at_css('script[type="application/ld+json"]')

    assert_equal({ "@context" => "https://schema.org", "@type" => "Thing", "name" => "Jane Smith" }, JSON.parse(script.text))
  end

  test "ld_json_tag escapes markup so it can't close the script tag" do
    html = ld_json_tag(name: "</script><b>x")

    assert_not_includes html, "</script><b>x"
    assert_equal "</script><b>x", JSON.parse(Nokogiri::HTML.fragment(html).at_css("script").text)["name"]
  end

  test "ld_json_event describes the show as a MusicEvent with only the city in its address" do
    show = shows(:upcoming)

    event = ld_json_event(show)

    assert_equal "MusicEvent", event[:@type]
    assert_equal show.event_name, event[:name]
    assert_equal show.start.iso8601, event[:startDate]
    assert_equal show.doors.iso8601, event[:doorTime]
    assert_equal show.blurb, event[:description]
    assert_equal({ "@type": "Organization", name: Settings.site_name, url: root_url }, event[:organizer])
    assert_equal({ "@type": "PostalAddress", addressLocality: "Brooklyn", addressRegion: "NY", addressCountry: "US" },
                 event.dig(:location, :address))
  end

  test "ld_json_event describes a show without a blurb by its event name" do
    show = shows(:upcoming)
    show.blurb = ""

    assert_equal show.event_name, ld_json_event(show)[:description]
  end

  test "ld_json_event lists each artist as a performer, and none for a show without artists" do
    show = shows(:upcoming)
    show.artists << Artist.create!(name: "Second Artist")

    assert_equal [ artists(:one).name, "Second Artist" ], ld_json_event(show)[:performer].pluck(:name)
    assert_equal show.artists.map(&:photo_url), ld_json_event(show)[:image]

    show.artists = []
    assert_equal [], ld_json_event(show.reload)[:performer]
  end

  test "ld_json_event links to and offers seats for a show taking RSVPs" do
    show = shows(:upcoming)

    event = ld_json_event(show)

    assert_equal rsvp_for_show_url(slug: show.slug), event[:url]
    assert_equal 20, event.dig(:offers, :price)
    assert_equal "USD", event.dig(:offers, :priceCurrency)
    assert_equal show.created_at.iso8601, event.dig(:offers, :validFrom)
    assert_equal "https://schema.org/InStock", event.dig(:offers, :availability)
  end

  test "ld_json_event marks a sold-out or waitlisted show's offer sold out" do
    shows(:upcoming).update!(availability: "waitlisted")

    assert_equal "https://schema.org/SoldOut", ld_json_event(shows(:upcoming)).dig(:offers, :availability)
    assert_equal "https://schema.org/SoldOut", ld_json_event(shows(:sold_out)).dig(:offers, :availability)
  end

  test "ld_json_event has no URL or offer for a past show" do
    event = ld_json_event(shows(:past))

    assert_not event.key?(:url)
    assert_not event.key?(:offers)
  end
end

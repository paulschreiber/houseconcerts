require "test_helper"

class ShowsControllerTest < ActionDispatch::IntegrationTest
  test "index lists upcoming shows" do
    get root_path

    assert_response :success
    assert_select "h2", text: shows(:upcoming).name
  end

  test "index fetches the first show's first photo first, and only that one" do
    attach_photo(artists(:one))
    shows(:upcoming).artists << attach_photo(Artist.create!(name: "Jane Smith"))

    get root_path

    photos = css_select("img.artist")
    assert_operator photos.size, :>, 1
    assert_equal "high", photos.first["fetchpriority"]
    assert_select "img.artist[fetchpriority]", count: 1
  end

  test "index offers a Reserve Seats button for an available show" do
    get root_path

    assert_select "form[action=?]", rsvp_for_show_path(slug: shows(:upcoming).slug)
  end

  test "index notes the waiting list and still offers the button for a waitlisted show" do
    shows(:upcoming).update!(availability: "waitlisted")

    get root_path

    assert_includes response.body, "Please RSVP now to be added to the waiting list."
    assert_select "form[action=?]", rsvp_for_show_path(slug: shows(:upcoming).slug)
  end

  test "index says a sold-out show is sold out, without the button" do
    shows(:upcoming).update!(availability: "sold_out")

    get root_path

    assert_includes response.body, "This show is sold out."
    assert_select "form[action=?]", rsvp_for_show_path(slug: shows(:upcoming).slug), false
  end

  test "index preloads artists and venues instead of querying per show" do
    Show.create!(name: "Another Upcoming Show", venue: create_venue, price: 20,
                 artists: [ artists(:one) ], start: 2.months.from_now)

    attach_photo(artists(:one))

    assert_queries_match(/FROM `artists`/, count: 1) do
      assert_queries_match(/FROM `venues`/, count: 1) do
        assert_queries_match(/FROM `active_storage_attachments`/, count: 1) { get root_path }
      end
    end

    assert_response :success
  end

  test "index shows each artist's photo, leaving out artists without one" do
    shows(:upcoming).artists << attach_photo(Artist.create!(name: "Jane Smith"))

    get root_path

    assert_select "img.artist", count: 1
    assert_select "img.artist[alt=?]", "Jane Smith"
  end

  test "index uses the next show's artist photo as its social media image" do
    attach_photo(artists(:one))

    get root_path

    assert_match %r{/rails/active_storage/representations/proxy/.+/test-artist\.jpg\z}, css_select("meta[property='og:image']").first["content"]
  end

  test "past shows use the site image as their social media image" do
    get past_shows_path

    assert_select "meta[property='og:image'][content=?]", "http://example.com/concerts.png"
  end

  test "index shows a message when there are no upcoming shows" do
    Show.update_all(status: "cancelled") # rubocop:disable Rails/SkipsModelValidations

    get root_path

    assert_response :success
    assert_select "h2", text: "No shows scheduled"
  end

  test "shows lists past shows" do
    get past_shows_path

    assert_response :success
  end

  test "shows preloads artists and venues instead of querying per show" do
    shows(:past).artists << artists(:one)
    Show.create!(name: "Another Past Show", venue: create_venue, price: 20,
                 artists: [ artists(:one) ], start: 2.months.ago)

    attach_photo(artists(:one))

    assert_queries_match(/FROM `artists`/, count: 1) do
      assert_queries_match(/FROM `venues`/, count: 1) do
        assert_queries_match(/FROM `active_storage_attachments`/, count: 1) { get past_shows_path }
      end
    end

    assert_response :success
  end

  test "shows escapes an artist name containing HTML instead of rendering it raw" do
    artist = artists(:one)
    artist.update!(name: "Evil<script>alert(1)</script>Artist")
    shows(:past).artists = [ artist ]

    get past_shows_path

    assert_response :success
    assert_not_includes @response.body, "<script>alert(1)</script>"
    assert_includes @response.body, "&lt;script&gt;"
  end

  test "shows a past show's photo as a thumbnail linking to the artist" do
    shows(:past).artists = [ attach_photo(artists(:one)) ]

    get past_shows_path

    assert_select "a.imagelink[href=?] img.artist[width='50'][height='50']", artists(:one).url
  end

  test "shows omits the image link wrapper when the sampled artist has no url" do
    artist = attach_photo(artists(:one))
    artist.update!(url: nil)
    shows(:past).artists = [ artist ]

    get past_shows_path

    assert_response :success
    assert_select "img.artist", count: 1
    assert_no_match(/<a class=.imagelink./, @response.body)
  end

  test "shows a past show without a photo when none of its artists has one" do
    shows(:past).artists = [ artists(:one) ]

    get past_shows_path

    assert_select "div.artists", text: /#{artists(:one).name}/
    assert_select "img.artist", false
  end

  test "shows renders an artist's name as plain text instead of a link when they have no url" do
    artist = artists(:one)
    artist.update!(url: nil)
    shows(:past).artists = [ artist ]

    get past_shows_path

    assert_response :success
    assert_select "div.artists", text: artist.name
    assert_select "div.artists a", false
  end

  test "index embeds each upcoming show as JSON-LD" do
    get root_path

    assert_includes ld_json_event_names, shows(:upcoming).event_name
  end

  # Google doesn't show past events in event results, and flags the missing
  # offers on events that can't be booked.
  test "shows doesn't embed past shows as JSON-LD" do
    shows(:past).artists << artists(:one)

    get past_shows_path

    assert_response :success
    assert_empty ld_json_event_names
  end

  test "shows shows a message when there are no past shows" do
    Show.update_all(status: "cancelled") # rubocop:disable Rails/SkipsModelValidations

    get past_shows_path

    assert_response :success
    assert_select "h2", text: "No shows found"
    assert_not_includes response.body, "</ol>"
  end

  test "the calendar feed is at /calendar and /calendar.ics, and no other format" do
    get "/calendar.ics"
    assert_response :success
    assert_equal "text/calendar", @response.media_type

    get "/calendar.json"
    assert_response :not_found
  end

  test "calendar returns an ics feed of upcoming shows" do
    show = shows(:upcoming)

    get calendar_path

    assert_response :success
    assert_equal "text/calendar", @response.media_type
    assert_includes @response.body, "BEGIN:VCALENDAR"
    assert_includes @response.body, "SUMMARY:#{show.event_name}"
    assert_includes @response.body, "DTSTART:#{show.start.utc.strftime('%Y%m%dT%H%M%SZ')}"
    assert_includes @response.body, "DTEND:#{show.end.utc.strftime('%Y%m%dT%H%M%SZ')}"
    assert_includes @response.body, "UID:event-#{show.slug}@#{Settings.domain}"
    assert_includes @response.body, rsvp_for_show_url(slug: show.slug)
    # Matches Icalendar::Values::Text#value_ical's own escaping order: a
    # literal backslash must be doubled before the comma is escaped, or an
    # input containing one would produce a different result than the gem's.
    escaped_location = show.location.gsub("\\") { "\\\\" }.gsub(",", "\\,")
    assert_includes @response.body, "LOCATION:#{escaped_location}"
  end

  test "calendar excludes past shows" do
    get calendar_path

    assert_response :success
    assert_not_includes @response.body, "SUMMARY:#{shows(:past).event_name}"
  end

  test "about mentions Twilio only when text messages are set up" do
    get about_path
    assert_includes response.body, "Twilio"

    with_stubbed(SendTextMessage, :enabled?, -> { false }) do
      get about_path
    end
    assert_not_includes response.body, "Twilio"
  end

  test "about renders the about page" do
    get about_path

    assert_response :success
  end

  test "musicians renders the musician info page" do
    get musicians_path

    assert_response :success
  end

  private

    def ld_json_event_names
      css_select('script[type="application/ld+json"]').map { |script| JSON.parse(script.text)["name"] }
    end
end

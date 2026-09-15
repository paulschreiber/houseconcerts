require "test_helper"

class ShowsControllerTest < ActionDispatch::IntegrationTest
  test "index lists upcoming shows" do
    get root_path

    assert_response :success
    assert_select "h2", text: shows(:upcoming).name
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

  test "shows preloads artists instead of querying per show" do
    shows(:past).artists << artists(:one)
    Show.create!(name: "Another Past Show", venue: venues(:one), price: 20, artists: [ artists(:one) ],
                 start: 2.months.ago, end: 2.months.ago + 2.hours)

    artist_queries = 0
    callback = ->(*, payload) { artist_queries += 1 if payload[:name] == "Artist Load" }

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      get past_shows_path
    end

    assert_response :success
    assert_equal 1, artist_queries
  end

  test "shows escapes an artist name containing HTML instead of rendering it raw" do
    artist = artists(:one)
    # ModelCleaners strips HTML from string attributes on save, so bypass it
    # to test the view's own escaping rather than relying on that callback.
    artist.update_column(:name, "Evil<script>alert(1)</script>Artist") # rubocop:disable Rails/SkipsModelValidations
    shows(:past).artists = [ artist ]

    get past_shows_path

    assert_response :success
    assert_not_includes @response.body, "<script>alert(1)</script>"
    assert_includes @response.body, "&lt;script&gt;"
  end

  test "shows omits the image link wrapper when the sampled artist has no url" do
    artist = artists(:one)
    artist.update!(url: nil)
    shows(:past).artists = [ artist ]

    get past_shows_path

    assert_response :success
    assert_no_match(/<a class=.imagelink./, @response.body)
  end

  test "shows renders an artist's name as plain text instead of a link when they have no url" do
    artist = artists(:one)
    artist.update!(url: nil)
    shows(:past).artists = [ artist ]

    get past_shows_path

    assert_response :success
    assert_select "span.fn", text: artist.name
    assert_select "a.url.fn", false
  end

  test "shows shows a message when there are no past shows" do
    Show.update_all(status: "cancelled") # rubocop:disable Rails/SkipsModelValidations

    get past_shows_path

    assert_response :success
    assert_select "h2", text: "No shows found"
  end

  test "calendar returns an ics feed of upcoming shows" do
    show = shows(:upcoming)

    get calendar_path

    assert_response :success
    assert_equal "text/calendar", @response.media_type
    assert_includes @response.body, "BEGIN:VCALENDAR"
    assert_includes @response.body, "SUMMARY:#{show.name} House Concert"
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
    assert_not_includes @response.body, "SUMMARY:#{shows(:past).name} House Concert"
  end

  test "about renders the about page" do
    get about_path

    assert_response :success
  end

  test "musicians renders the musician info page" do
    get musicians_path

    assert_response :success
  end
end

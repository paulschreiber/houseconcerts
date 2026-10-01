require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "page_title falls back to just the site name" do
    assert_equal Settings.site_name, page_title
  end

  test "page_title prepends a show's name" do
    assert_equal "#{shows(:upcoming).name} » #{Settings.site_name}", page_title(shows(:upcoming))
  end

  test "page_title prepends an arbitrary string" do
    assert_equal "About » #{Settings.site_name}", page_title("About")
  end

  test "social_media_title falls back to just the site name when there is no show" do
    assert_equal Settings.site_name, social_media_title(nil)
  end

  test "social_media_title includes the show's name and date" do
    show = shows(:upcoming)

    assert_equal "#{show.name} » #{show.start_date_short} » #{Settings.site_name}", social_media_title(show)
  end

  test "social_media_description falls back to the meta description when there is no show" do
    assert_equal Settings.meta_description, social_media_description(nil)
  end

  test "social_media_description falls back to the meta description when the show has no artists" do
    show = shows(:past)
    assert_empty show.artists

    assert_equal Settings.meta_description, social_media_description(show)
  end

  test "social_media_description describes a show with artists and a location" do
    show = shows(:upcoming)

    assert_equal(
      "Reserve seats for the #{show.name} house concert in #{show.location} on #{show.start_date}",
      social_media_description(show)
    )
  end

  test "canonical_url strips the query string" do
    @request = ActionDispatch::TestRequest.create(Rack::MockRequest.env_for("/about?utm_source=test"))

    assert_equal "http://test.host/about", canonical_url
  end

  test "social_media_image uses the show's first artist photo when the show has artists" do
    show = shows(:upcoming)

    assert_equal root_url + show.artists.first.photo, social_media_image(show)
  end

  test "social_media_image falls back to the next upcoming show's photo on the home page" do
    @request = ActionDispatch::TestRequest.create(Rack::MockRequest.env_for("/"))

    assert_equal root_url + shows(:upcoming).artists.first.photo, social_media_image(nil)
  end

  test "social_media_image falls back to the site image off the home page with no show" do
    @request = ActionDispatch::TestRequest.create(Rack::MockRequest.env_for("/about"))

    assert_equal "#{root_url}concerts.png", social_media_image(nil)
  end

  test "analytics_url replaces link tokens in every tokened path" do
    {
      "https://houseconcerts.nyc/rsvps/show/jen-lowe-4/abc123" => "https://houseconcerts.nyc/rsvps/show/jen-lowe-4/:uniqid",
      "https://houseconcerts.nyc/rsvps/show/jen-lowe-4/abc123/no" => "https://houseconcerts.nyc/rsvps/show/jen-lowe-4/:uniqid/no",
      "https://houseconcerts.nyc/rsvps/thanks/abc123" => "https://houseconcerts.nyc/rsvps/thanks/:uniqid",
      "https://houseconcerts.nyc/list/thanks/abc123" => "https://houseconcerts.nyc/list/thanks/:uniqid",
      "https://houseconcerts.nyc/unsubscribe/abc123" => "https://houseconcerts.nyc/unsubscribe/:uniqid"
    }.each do |url, expected|
      assert_equal expected, analytics_url(url), url
    end
  end

  test "analytics_url leaves ordinary pages alone" do
    assert_equal "https://houseconcerts.nyc/about", analytics_url("https://houseconcerts.nyc/about")
    assert_equal "https://houseconcerts.nyc/rsvps/show/jen-lowe-4", analytics_url("https://houseconcerts.nyc/rsvps/show/jen-lowe-4")
  end

  test "analytics_url keeps only utm_ query parameters" do
    url = "https://houseconcerts.nyc/rsvps/show/jen-lowe-4?rsvp%5Bemail%5D=jane%40example.com&utm_source=email&utm_campaign=invite#top"

    assert_equal "https://houseconcerts.nyc/rsvps/show/jen-lowe-4?utm_source=email&utm_campaign=invite", analytics_url(url)
    assert_equal "https://houseconcerts.nyc/list", analytics_url("https://houseconcerts.nyc/list?first_name=Jane")
  end

  test "analytics_url returns nil for blank or unparseable input" do
    assert_nil analytics_url(nil)
    assert_nil analytics_url("")
    assert_nil analytics_url("http://exa mple.com/ bad")
  end

  test "the Google Analytics snippet sends the page and referrer without tokens" do
    env = Rack::MockRequest.env_for(
      "https://houseconcerts.nyc/rsvps/show/jen-lowe-4/abc123?rsvp%5Bemail%5D=jane%40example.com",
      "HTTP_REFERER" => "https://houseconcerts.nyc/unsubscribe/def456"
    )
    controller.request = ActionDispatch::TestRequest.create(env)
    controller.request.session = ActionController::TestSession.new # for the CSP nonce

    html = render(partial: "application/google_analytics")

    assert_match %r{"page_location":"https://[^"/]+/rsvps/show/jen-lowe-4/:uniqid"}, html
    assert_includes html, %("page_referrer":"https://houseconcerts.nyc/unsubscribe/:uniqid")
    assert_not_includes html, "abc123"
    assert_not_includes html, "def456"
    assert_not_includes html, "jane"
  end
end

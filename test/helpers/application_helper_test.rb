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
end

require "test_helper"

class DashboardHelperTest < ActionView::TestCase
  test "dashboard_time is relative within a day, then yesterday, then a date" do
    travel_to Time.zone.local(2026, 10, 5, 12) do
      assert_equal "about 2 hours ago", dashboard_time(2.hours.ago)
      assert_equal "yesterday", dashboard_time(Time.zone.local(2026, 10, 4, 8))
      assert_equal "Oct 2", dashboard_time(Time.zone.local(2026, 10, 2, 8))
      assert_equal "Dec 30, 2025", dashboard_time(Time.zone.local(2025, 12, 30, 8))
    end
  end

  test "days_until says today, tomorrow, or in how many days" do
    travel_to Time.zone.local(2026, 10, 5, 12) do
      assert_equal "today", days_until(Show.new(start: Time.zone.local(2026, 10, 5, 19)))
      assert_equal "tomorrow", days_until(Show.new(start: Time.zone.local(2026, 10, 6, 19)))
      assert_equal "in 12 days", days_until(Show.new(start: Time.zone.local(2026, 10, 17, 19)))
    end
  end

  test "show_badge colors availability and status" do
    assert_dom_equal %(<span class="badge badge--green">Available</span>), show_badge("available")
    assert_dom_equal %(<span class="badge badge--red">Sold out</span>), show_badge("sold_out")
    assert_dom_equal %(<span class="badge">Unconfirmed</span>), show_badge("unconfirmed")
  end

  test "open_message names the show and email type from the tag" do
    shows_by_slug = { shows(:upcoming).slug => shows(:upcoming) }

    assert_equal "#{shows(:upcoming).name} invite", open_message(Open.new(tag: "#{shows(:upcoming).slug}:invite"), shows_by_slug)
    assert_equal "gone-show remind", open_message(Open.new(tag: "gone-show:remind"), shows_by_slug)
    assert_equal "", open_message(Open.new, shows_by_slug)
  end

  test "rsvp_graph draws a line per show, and marks today on the next show's" do
    past = Dashboard::Series.new(show: shows(:past), points: [ [ 10, 2 ], [ 0, 5 ] ], next_show: false)
    upcoming = Dashboard::Series.new(show: shows(:upcoming), points: [ [ 20, 4 ], [ 12, 6 ] ], next_show: true)

    svg = Nokogiri::HTML5.fragment(rsvp_graph([ past, upcoming ]))

    assert_equal 2, svg.css("path").size
    assert_equal "Today: 6 seats", svg.at_css("text.today").text
    assert_equal [ "Show day", "7 days before", "14 days before", "21 days before" ], svg.css("text").map(&:text).grep(/Show day|days before/)
    assert_equal "start", svg.at_css("text.today")["text-anchor"]
  end

  test "rsvp_graph puts the today label left of a point near show day" do
    upcoming = Dashboard::Series.new(show: shows(:upcoming), points: [ [ 20, 4 ], [ 1, 6 ] ], next_show: true)

    svg = Nokogiri::HTML5.fragment(rsvp_graph([ upcoming ]))

    assert_equal "end", svg.at_css("text.today")["text-anchor"]
  end
end

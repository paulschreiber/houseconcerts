require "test_helper"

class DashboardGraphHelperTest < ActionView::TestCase
  SHOWS_BY_ROLE = { past: :past, next: :upcoming, following: :sold_out }.freeze

  test "rsvp_graph draws a line per show, marks today on upcoming shows' and labels the next show's" do
    svg = graph(series(:past, [ 10, 2 ], [ 0, 5 ]), series(:next, [ 20, 4 ], [ 12, 6 ]), series(:following, [ 21, 1 ], [ 13, 3 ]))
          .at_css("svg.graph-desktop")

    assert_equal 3, svg.css("path").size
    assert_equal 2, svg.css("circle").size
    assert_equal 1, svg.css("text.today").size
    assert_equal "Today: 6 seats", svg.at_css("text.today").text
    assert_equal [ "Show day", *(7..49).step(7).map { |days| "#{days} days before" } ], svg.css("text[y='190']").map(&:text)
    assert_equal "start", svg.at_css("text.today")["text-anchor"]
  end

  test "rsvp_graph labels today on the following show's line when the next show has none" do
    svg = graph(series(:following, [ 21, 1 ], [ 13, 3 ])).at_css("svg.graph-desktop")

    assert_equal "Today: 3 seats", svg.at_css("text.today").text
  end

  test "rsvp_graph puts the today label left of a point near show day" do
    assert_equal %w[end end], graph(series(:next, [ 20, 4 ], [ 1, 6 ])).css("text.today").pluck("text-anchor")
  end

  test "rsvp_graph puts the today label below a point at the top of the graph" do
    graph(series(:next, [ 20, 4 ], [ 12, 20 ])).css("svg").each do |svg|
      assert_operator svg.at_css("text.today")["y"].to_f, :>, svg.at_css("circle")["cy"].to_f, svg["class"]
    end
  end

  test "rsvp_graph puts the today label above a point below the top of the graph" do
    graph(series(:next, [ 20, 4 ], [ 12, 15 ])).css("svg").each do |svg|
      assert_operator svg.at_css("text.today")["y"].to_f, :<, svg.at_css("circle")["cy"].to_f, svg["class"]
    end
  end

  test "rsvp_graph draws a narrower graph for phones, labeled with just the number of days" do
    phone = graph(series(:next, [ 20, 4 ], [ 12, 6 ])).at_css("svg.graph-phone")

    assert_equal "0 0 400 220", phone["viewBox"]
    assert_equal 1, phone.css("path").size
    assert_equal (0..49).step(7).map(&:to_s), phone.css("text[y='210']").map(&:text)
  end

  private

    def series(role, *points)
      Dashboard::Series.new(show: shows(SHOWS_BY_ROLE.fetch(role)), points:, role:)
    end

    def graph(*all_series)
      Nokogiri::HTML5.fragment(rsvp_graph(all_series))
    end
end

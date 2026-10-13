require "test_helper"

class DashboardHelperTest < ActionView::TestCase
  test "dashboard_date is always a date, with the year if it isn't this year" do
    travel_to Time.zone.local(2026, 10, 5, 12) do
      assert_equal "Oct 5", dashboard_date(2.hours.ago)
      assert_equal "Oct 4", dashboard_date(Time.zone.local(2026, 10, 4, 8))
      assert_equal "Dec 30, 2025", dashboard_date(Time.zone.local(2025, 12, 30, 8))
    end
  end

  test "all_count_label leaves out All for a single item" do
    assert_equal "All 33 RSVPs", all_count_label(33, "RSVP")
    assert_equal "1 unconfirmed RSVP", all_count_label(1, "unconfirmed RSVP")
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

    assert_dom_equal %(#{show_name_with_initials(shows(:upcoming).name)} invite),
                     open_message(Open.new(tag: "#{shows(:upcoming).slug}:invite"), shows_by_slug)
    assert_equal "gone-show remind", open_message(Open.new(tag: "gone-show:remind"), shows_by_slug)
    assert_equal "", open_message(Open.new, shows_by_slug)
  end

  test "show_name_with_initials pairs the name with its capitalized words' initials" do
    assert_dom_equal %(<span class="show-name">Delia &amp; the Lanterns</span><abbr title="Delia &amp; the Lanterns" class="show-initials">DL</abbr>),
                     show_name_with_initials("Delia & the Lanterns")
    assert_equal "DC", Nokogiri::HTML5.fragment(show_name_with_initials("Damon Castillo")).at_css("abbr").text
    assert_equal "tl", Nokogiri::HTML5.fragment(show_name_with_initials("the lumineers")).at_css("abbr").text
  end
end

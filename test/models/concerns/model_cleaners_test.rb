require "test_helper"

class ModelCleanersTest < ActiveSupport::TestCase
  test "saving trims whitespace and keeps the text as typed" do
    artist = artists(:one)
    artist.update!(name: "  Smith & Li <b>Jones</b> &lt;3  ")

    assert_equal "Smith & Li <b>Jones</b> &lt;3", artist.reload.name
  end

  test "validation checks the cleaned text" do
    # 15,000 characters as typed, 9,999 once trimmed and with \n line breaks.
    message = shows(:upcoming).invite_messages.new(intro: "a\r\n" * 5_000, about: "About")

    assert_predicate message, :valid?
    assert_equal 9_999, message.intro.length
  end

  test "saving stores a textarea's CRLF line breaks as LF" do
    venue = venues(:one)
    venue.update!(directions: "Line 1\r\nline 2")

    assert_equal "Line 1\nline 2", venue.reload.directions
  end
end

require "test_helper"

class TextCleanerTest < ActiveSupport::TestCase
  test "trims whitespace at both ends, including the kinds String#strip misses" do
    assert_equal "Jane", TextCleaner.clean("  \t Jane \n ")
    assert_equal "Jane", TextCleaner.clean("\u00a0\u2003Jane\u3000")
  end

  test "stores every kind of line break as a newline" do
    assert_equal "a\nb\nc\nd\ne\nf\ng\nh", TextCleaner.clean("a\r\nb\rc\nd\u2028e\u0085f\vg\fh")
    assert_equal "a\n\nb", TextCleaner.clean("a\r\n\r\nb")
  end

  test "keeps tabs and markup as typed" do
    assert_equal "a\tb <b>c</b> &lt;3", TextCleaner.clean("a\tb <b>c</b> &lt;3")
  end

  test "removes characters nobody can see" do
    [ "\u0000", "\u0007", "\u007f", "\u200B", "\u200C", "\u200D", "\u200E", "\u202A", "\u202E", "\u2066", "\u2060", "\uFEFF", "\u00AD" ].each do |hidden|
      assert_equal "ab", TextCleaner.clean("a#{hidden}b"), hidden.inspect
    end
  end

  test "keeps text in other scripts and emoji" do
    assert_equal "Zoë Ñandú 北京 שלום 🎸", TextCleaner.clean("Zoë Ñandú 北京 שלום 🎸")
  end

  test "one_line turns line breaks and tabs into single spaces" do
    assert_equal "First. Second. Third.", TextCleaner.clean("First.\r\n Second.\n\n  Third.\n", one_line: true)
    assert_equal "a b", TextCleaner.clean("a\u2028b", one_line: true)
    assert_equal "a b c", TextCleaner.clean("a\tb \t c", one_line: true)
    assert_equal "Jane Smith", TextCleaner.clean("Jane\n\u200B\nSmith", one_line: true)
  end

  test "returns binary or invalid text as it is" do
    binary = "a\x00\xFF".b
    invalid = "a\xFF".dup.force_encoding("UTF-8")

    assert_same binary, TextCleaner.clean(binary)
    assert_same invalid, TextCleaner.clean(invalid)
  end

  test "cleans text that is frozen, without changing it" do
    text = " Jane\u200B ".freeze

    assert_equal "Jane", TextCleaner.clean(text)
    assert_equal " Jane\u200B ", text
  end
end

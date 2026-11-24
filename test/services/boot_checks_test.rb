require "test_helper"

class BootChecksTest < ActiveSupport::TestCase
  Check = Struct.new(:problems)

  test "passes when no check has a problem" do
    assert_nothing_raised { BootChecks.call([ Check.new([]), Check.new([]) ]) }
  end

  test "raises listing the problems of every check" do
    error = assert_raises(BootChecks::Failed) { BootChecks.call([ Check.new([ "first" ]), Check.new([]), Check.new(%w[second third]) ]) }

    assert_equal "The app can’t start:\n- first\n- second\n- third", error.message
  end

  test "runs the required settings check" do
    assert_equal [ BootChecks::RequiredSettings ], BootChecks.checks
  end
end

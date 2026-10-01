require "test_helper"

class RegexpTimeoutTest < ActiveSupport::TestCase
  test "sets a global regex timeout" do
    assert_equal 1.0, Regexp.timeout
  end

  # Ruby's match cache makes most backtracking patterns linear, but not ones
  # with backreferences, so this one still runs until the timeout.
  test "a catastrophically backtracking regex is cut off instead of hanging" do
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    assert_raises(Regexp::TimeoutError) { /\A(a|aa)+\1b\z/.match?("#{'a' * 40}bX") }
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 5
  end
end

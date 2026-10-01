require "test_helper"

class RegexpTimeoutTest < ActiveSupport::TestCase
  test "sets a global regex timeout" do
    assert_equal 1.0, Regexp.timeout
  end

  test "a catastrophically backtracking email is cut off instead of hanging" do
    rsvp = rsvps(:one)
    rsvp.email = "a@#{'a.' * 30}!"

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    assert_raises(Regexp::TimeoutError) { rsvp.valid? }
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 5
  end
end

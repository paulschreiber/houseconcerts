require "test_helper"

class SiteHealthTest < ActiveSupport::TestCase
  Check = Struct.new(:title, :problems)

  test "results give each check's title and problems" do
    results = SiteHealth.results([ Check.new("Email", []), Check.new("Texts", [ "Missing credentials." ]) ])

    assert_equal %w[Email Texts], results.map(&:title)
    assert_equal [ true, false ], results.map(&:passed?)
  end

  test "failures are the results with problems" do
    failures = SiteHealth.failures([ Check.new("Email", []), Check.new("Texts", [ "Missing credentials." ]) ])

    assert_equal [ "Texts" ], failures.map(&:title)
    assert_equal [ "Missing credentials." ], failures.first.problems
  end

  test "runs the SES and Twilio checks" do
    assert_equal [ SiteHealth::SesCredentials, SiteHealth::TwilioCredentials ], SiteHealth.checks
  end
end

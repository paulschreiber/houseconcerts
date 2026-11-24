# Checks of the site’s health, shown on a backstage page (see
# Madmin::SiteHealthController) and, when one fails, as a banner on the
# dashboard. Unlike BootChecks, they cover things the app can run without, such
# as email and text messages that can't be sent. Each check in `checks`
# responds to `title` and `problems`, which returns a list of messages, empty
# when all is well. To add a check, write one and add it to `checks`.
module SiteHealth
  Result = Data.define(:title, :problems) do
    def passed?
      problems.empty?
    end
  end

  def self.checks
    [ SesCredentials, TwilioCredentials ]
  end

  def self.results(checks = self.checks)
    checks.map { |check| Result.new(check.title, check.problems) }
  end

  def self.failures(...)
    results(...).reject(&:passed?)
  end
end

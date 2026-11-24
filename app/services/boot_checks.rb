# Checks that run when the app boots, so a problem shows up as a failed boot
# (and a failed deploy) instead of as a crash on the first request that needs
# it. They cover only what the app needs in order to boot; broader checks of
# the site’s setup belong on an admin page. Each check in `checks` responds to
# `problems`, which returns a list of messages, empty when all is well. To add
# a check, write one and add it to `checks`; they all run, so one failed boot
# lists every problem.
module BootChecks
  class Failed < StandardError; end

  def self.checks
    [ RequiredSettings ]
  end

  def self.call(checks = self.checks)
    problems = checks.flat_map(&:problems)
    raise Failed, "The app can’t start:\n#{problems.map { "- #{_1}" }.join("\n")}" if problems.any?
  end
end

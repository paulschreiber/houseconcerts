# Times are shown in the site's time zone (the time_zone setting), which an
# admin can change, so it's set for each request and job rather than once at
# boot. config.time_zone (in application.rb) is the default for everything else.
class SiteTimeZone
  # The setting's zone, or the default one if the setting isn't a zone we know.
  # It reads the stored value, not Settings, so starting a request or job
  # doesn't build the settings before the request has changed them. A time
  # zone is only for display, so if the setting can't be read (before the
  # database has its tables, say) it's the default, and logged, rather than
  # failing the request or job.
  def self.zone
    ActiveSupport::TimeZone[Settings.stored["time_zone"].to_s] || ActiveSupport::TimeZone[Defaults.time_zone]
  rescue StandardError => e
    Rails.logger.warn("Using the default time zone, since the time_zone setting couldn't be read: #{e.class}: #{e.message}")
    ActiveSupport::TimeZone[Defaults.time_zone]
  end

  # An executor hook: the executor wraps every request and job (and the mail
  # they send).
  def run
    previous = ActiveSupport::IsolatedExecutionState[:time_zone]
    Time.zone = self.class.zone
    previous
  end

  # previous is the zone that was set before run, or nil if none was, so
  # Time.zone goes back to the default.
  def complete(previous)
    Time.zone = previous
  end
end

Rails.application.executor.register_hook(SiteTimeZone.new)
Rails.application.console { Time.zone = SiteTimeZone.zone }

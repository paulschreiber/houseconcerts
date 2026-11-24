# Times are shown in the site's time zone (the time_zone setting), which an
# admin can change, so it's set for each request and job rather than once at
# boot. config.time_zone (in application.rb) is the default for everything else.
class SiteTimeZone
  # The setting's zone, or the default one if the setting isn't a zone we know.
  # It reads the stored value, not Settings, so starting a request or job
  # doesn't build the settings before the request has changed them. If the
  # database can't be read (before its tables exist, say), it's the default.
  def self.zone
    ActiveSupport::TimeZone[Settings.stored["time_zone"].to_s] || ActiveSupport::TimeZone[Defaults.time_zone]
  rescue ActiveRecord::ActiveRecordError
    ActiveSupport::TimeZone[Defaults.time_zone]
  end

  # An executor hook: the executor wraps every request and job (and the mail
  # they send).
  def run
    previous = Time.zone
    Time.zone = self.class.zone
    previous
  end

  def complete(previous)
    Time.zone = previous
  end
end

Rails.application.executor.register_hook(SiteTimeZone.new)
Rails.application.console { Time.zone = SiteTimeZone.zone }

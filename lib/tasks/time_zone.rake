# The tasks that print or send times run in the site's time zone, like requests
# and jobs do (see config/initializers/time_zone.rb).
desc "Use the site's time zone, for the tasks that print or send times"
task site_time_zone: :environment do
  Time.zone = SiteTimeZone.zone
end

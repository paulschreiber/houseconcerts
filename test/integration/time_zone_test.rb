require "test_helper"

# Times are shown in the time_zone setting, which an admin can change: the
# executor sets it for each request and job (config/initializers/time_zone.rb).
class TimeZoneTest < ActionDispatch::IntegrationTest
  PACIFIC = "Pacific Time (US & Canada)".freeze

  test "the zone is the default one until the setting is changed" do
    assert_equal Defaults.time_zone, SiteTimeZone.zone.name
    assert_equal Defaults.time_zone, Time.zone.name
  end

  test "a request shows times in the time zone setting" do
    sign_in admins(:one)

    with_setting("time_zone", PACIFIC) do
      get madmin_setting_path("email")
    end

    assert_select ".form-description", text: "In the site’s time zone (#{PACIFIC})."
    assert_equal Defaults.time_zone, Time.zone.name, "the test's own zone isn't changed"
  end

  test "the hook sets the zone, and puts the previous one back" do
    hook = SiteTimeZone.new

    with_setting("time_zone", PACIFIC) do
      previous = hook.run

      assert_equal PACIFIC, Time.zone.name
      hook.complete(previous)
    end
    assert_equal Defaults.time_zone, Time.zone.name
  end

  test "a time zone that can't be read falls back to the default" do
    with_stubbed(Settings, :stored, -> { raise ActiveRecord::StatementInvalid, "no setting_values table" }) do
      assert_equal Defaults.time_zone, SiteTimeZone.zone.name
    end
  end

  # Records the time zone it ran in.
  class ZoneJob < ApplicationJob
    cattr_accessor :zone_name

    def perform
      self.class.zone_name = Time.zone.name
    end
  end

  # Active Job runs a job in the zone it was enqueued in, so a job enqueued in a
  # request or by the scheduler (both in an executor) runs in the site's zone.
  # The test's thread is already in an executor, so the job's thread isn't.
  test "a job enqueued in an executor runs in the time zone setting" do
    job_data = nil
    with_setting("time_zone", PACIFIC) do
      Thread.new { Rails.application.executor.wrap { job_data = ZoneJob.new.serialize } }.join
    end

    assert_equal PACIFIC, job_data["timezone"]
    Thread.new { ZoneJob.execute(job_data) }.join

    assert_equal PACIFIC, ZoneJob.zone_name
  end

  test "a setting that can't be read is logged, and the default zone is used" do
    with_stubbed(Settings, :stored, -> { raise TypeError, "bad cache" }) do
      assert_equal Defaults.time_zone, SiteTimeZone.zone.name
    end
  end

  test "an unknown time zone falls back to the default" do
    SettingValue.new(key: "time_zone", value: "Mars/Olympus").save!(validate: false)
    Settings.expire

    assert_equal Defaults.time_zone, SiteTimeZone.zone.name
  end

  test "a reminder goes out at its hour in the time zone setting" do
    show = shows(:upcoming)

    Time.use_zone(PACIFIC) do
      assert_equal 13, show.reminder_time.hour
      assert_equal PACIFIC, show.reminder_time.time_zone.name
    end
    # Pacific and Eastern change to daylight time together, so 1 pm Pacific is 4 pm Eastern all year.
    assert_equal 16, Time.use_zone(PACIFIC) { show.reminder_time.in_time_zone(Defaults.time_zone).hour }
  end

  test "the rake task that prints times sets the zone" do
    load_rake_tasks
    Rake::Task["site_time_zone"].reenable

    Time.use_zone(Defaults.time_zone) do
      with_setting("time_zone", PACIFIC) do
        Rake::Task["site_time_zone"].invoke

        assert_equal PACIFIC, Time.zone.name
      end
    end
  end
end

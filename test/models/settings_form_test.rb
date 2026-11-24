require "test_helper"

class SettingsFormTest < ActiveSupport::TestCase
  test "every setting a form edits can be stored" do
    keys = [ SettingsForm::Site, SettingsForm::Email, SettingsForm::Shows, SettingsForm::Location ].flat_map { |form| form.settings.values.pluck(:key) }

    assert_empty keys - Settings::EDITABLE
  end

  test "a save with no changes writes nothing" do
    SettingValue.create!(key: "show.duration", value: "3")
    form = SettingsForm::Shows.new

    assert_no_changes -> { SettingValue.pluck(:key, :value, :updated_at) } do
      assert form.save
    end
  end

  test "starts from the current settings" do
    with_setting("site_name", "Jane’s Concerts") do
      form = SettingsForm::Site.new

      assert_equal "Jane’s Concerts", form.site_name
      assert_equal Defaults.meta_description, form.meta_description
    end
  end

  test "saving stores only the values that differ from the defaults" do
    form = SettingsForm::Site.new(site_name: "Jane’s Concerts")

    assert form.save
    assert_equal [ "site_name" ], SettingValue.pluck(:key)
    assert_equal "Jane’s Concerts", Settings.site_name
  end

  test "setting a value back to its default removes it" do
    SettingValue.create!(key: "show.duration", value: "3")

    assert SettingsForm::Shows.new(duration: Defaults.show.duration).save
    assert_empty SettingValue.where(key: "show.duration")
    assert_equal Defaults.show.duration, Settings.show.duration
  end

  test "strips spaces from text" do
    form = SettingsForm::Site.new(site_name: "  Jane’s Concerts ")

    assert form.save
    assert_equal "Jane’s Concerts", Settings.site_name
  end

  test "an invalid form saves nothing" do
    form = SettingsForm::Site.new(site_name: "Jane’s Concerts", google_analytics_id: "UA-1")

    assert_not form.save
    assert_empty SettingValue.all
    assert_equal [ "Google Analytics ID should look like G-ABC123: a G, a dash, then capital letters and numbers" ], form.errors.full_messages
  end

  test "every text field is cleaned of hidden characters and outer whitespace" do
    form = SettingsForm::Site.new(site_name: "\u00a0Jane’s\u200B Concerts\u202E ", meta_description: "\ufeffA description\u0007 ",
                                  meta_keywords: "\u2003Music\u200D ", google_analytics_id: " G-ABC123\u200B ")

    assert_equal [ "Jane’s Concerts", "A description", "Music", "G-ABC123" ],
                 [ form.site_name, form.meta_description, form.meta_keywords, form.google_analytics_id ]
    assert form.save
    assert_equal "Jane’s Concerts", Settings.site_name
  end

  test "the site needs a name and a description" do
    form = SettingsForm::Site.new(site_name: "", meta_description: "")

    assert_not form.valid?
    assert_equal [ "Site name can't be blank", "Description can't be blank" ], form.errors.full_messages
  end

  test "line breaks in the description and keywords become spaces" do
    form = SettingsForm::Site.new(meta_description: "First line.\r\nSecond line.\n\n  Third.  ", meta_keywords: "Music,\nLive")

    assert form.save
    assert_equal "First line. Second line. Third.", Settings.meta_description
    assert_equal "Music, Live", Settings.meta_keywords
  end

  test "the site name is one line, since it goes into email subjects" do
    form = SettingsForm::Site.new(site_name: "Jane’s Concerts\r\nBcc: x@example.org")

    assert_equal "Jane’s Concerts Bcc: x@example.org", form.site_name
  end

  test "analytics can be blank, which turns it off" do
    form = SettingsForm::Site.new(google_analytics_id: "")

    assert form.save
    assert_equal "", Settings.google_analytics_id
  end

  test "email addresses are the part before the @" do
    [ "jane@example.org", "has space", "a,b", ".jane", "jane.", "a..b", "<jane>" ].each do |local|
      form = SettingsForm::Email.new(invites_from_email: local)

      assert_not form.valid?, local
      assert_equal [ "Email address can’t have spaces, commas or an @ (the domain is added for you), or start or end with a dot" ], form.errors.full_messages, local
    end
    assert SettingsForm::Email.new(invites_from_email: "jane.smith+concerts").valid?
  end

  test "an email address can't be blank" do
    form = SettingsForm::Email.new(invites_from_email: "", confirms_from_email: " ")

    assert_not form.valid?
    assert_equal [ "Email address can't be blank" ], form.errors.full_messages.uniq
    assert_not form.save
  end

  test "sender names can't hold anything that would break a From header" do
    [ "Jane <jane@example.org>", "Jane \"JS\" Smith" ].each do |name|
      form = SettingsForm::Email.new(invites_from_first_name: name)

      assert_not form.valid?, name.inspect
      assert_equal [ "First name can’t have angle brackets or quotation marks" ], form.errors.full_messages
    end
    assert SettingsForm::Email.new(invites_from_first_name: "Jane O’Brien-Smith").valid?
  end

  test "a line break in a sender name becomes a space, so it can't add a header" do
    form = SettingsForm::Email.new(invites_from_first_name: "Jane\r\nBcc: x@example.org")

    assert_equal "Jane Bcc: x@example.org", form.invites_from_first_name
    assert_equal "Jane Smith", SettingsForm::Email.new(invites_from_last_name: "Jane\tSmith").invites_from_last_name
    assert form.save
    assert_not_includes Settings.organization.invites_from_first_name, "\n"
  end

  test "the sign-off keeps its line breaks, and loses hidden characters" do
    form = SettingsForm::Email.new(guest_sign_off: "  See you soon,\r\nJane\u202E \u200B\n")

    assert form.save
    assert_equal "See you soon,\nJane", Settings.guest_sign_off
  end

  test "the sign-off can be blank, which signs off with the first name, but not very long" do
    assert SettingsForm::Email.new(guest_sign_off: " ").valid?
    assert_not SettingsForm::Email.new(guest_sign_off: "a" * 501).valid?
    assert SettingsForm::Email.new(guest_sign_off: "a" * 500).valid?
  end

  test "the reminder time is a whole hour, stored as an hour" do
    assert_equal "13:00", SettingsForm::Email.new.reminder_time

    form = SettingsForm::Email.new(reminder_time: "09:00")
    assert form.save
    assert_equal 9, Settings.reminders.hour

    assert_not SettingsForm::Email.new(reminder_time: "09:30").valid?
    assert_not SettingsForm::Email.new(reminder_time: "").valid?
  end

  test "the reminder days are a number from 0 to 30" do
    assert_not SettingsForm::Email.new(reminder_days: 31).valid?
    assert_not SettingsForm::Email.new(reminder_days: -1).valid?
    assert_not SettingsForm::Email.new(reminder_days: "").valid?
    assert SettingsForm::Email.new(reminder_days: 0).valid?
  end

  test "show settings are whole numbers in range" do
    assert_not SettingsForm::Shows.new(duration: 0).valid?
    assert_not SettingsForm::Shows.new(max_seats: 0).valid?
    assert_not SettingsForm::Shows.new(arrival_minutes: "soon").valid?
    assert_not SettingsForm::Shows.new(overbook_seats: -1).valid?
    assert SettingsForm::Shows.new(max_seats: 6).valid?
  end

  test "a minimum can't be more than its maximum" do
    form = SettingsForm::Shows.new(min_price: 50, max_price: 40, min_capacity: 30, max_capacity: 20)

    assert_not form.valid?
    assert_equal [ "Lowest can’t be more than the highest price", "Smallest can’t be more than the largest capacity" ], form.errors.full_messages
  end

  test "the RSVP notification is stored as yes, or blank for off" do
    assert SettingsForm::Shows.new.notify_rsvp

    assert SettingsForm::Shows.new(notify_rsvp: false).save
    assert_equal "", Settings.notify_rsvp

    assert SettingsForm::Shows.new(notify_rsvp: true).save
    assert_equal Defaults.notify_rsvp, Settings.notify_rsvp
    assert_empty SettingValue.where(key: "notify_rsvp")
  end

  test "the location needs a real country and venue group" do
    assert_not SettingsForm::Location.new(default_country: "ZZ").valid?
    assert_not SettingsForm::Location.new(default_venue_group: 0).valid?

    form = SettingsForm::Location.new(default_country: "CA", default_venue_group: venue_groups(:two).id)
    assert form.save
    assert_equal "CA", Settings.default_country
  end
end

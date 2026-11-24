require "application_system_test_case"

# Each settings tab is a form saved in the browser: fields, a checkbox and a
# time picker must send what they show.
class SettingsTest < ApplicationSystemTestCase
  setup do
    sign_in_as_admin
    visit madmin_setting_path("site")
  end

  test "saving a tab changes the setting and keeps the admin on the tab" do
    fill_in "Site name", with: "Jane’s Concerts"
    click_button "Update Site settings"

    assert_text "Site settings saved."
    assert_field "Site name", with: "Jane’s Concerts"
    assert_equal "Jane’s Concerts", saved_settings.site_name
  end

  test "a bad value shows its error next to the field and keeps what was typed" do
    click_link "Shows and RSVPs"
    fill_in "Lowest", with: "50"
    fill_in "Highest", with: "40"
    fill_in "Show length (hours)", with: "3"
    click_button "Update Shows and RSVPs settings"

    assert_text "can’t be more than the highest price"
    assert_field "Show length (hours)", with: "3"
    assert_equal Defaults.show.duration, saved_settings.show.duration
  end

  test "the checkbox and the time picker save what they show" do
    click_link "Shows and RSVPs"
    uncheck "Email me about each RSVP"
    click_button "Update Shows and RSVPs settings"

    assert_text "Shows and RSVPs settings saved."
    assert_unchecked_field "Email me about each RSVP"
    assert_equal "", saved_settings.notify_rsvp

    click_link "Email"
    fill_in "At", with: Time.zone.local(2000, 1, 1, 9)
    click_button "Update Email settings"

    assert_text "Email settings saved."
    assert_equal 9, saved_settings.reminders.hour
    assert_field "At", with: "09:00"
  end

  private

    # The settings as the server saved them: the test's thread keeps the ones it
    # read first (Current), and the server runs in another thread.
    def saved_settings
      Settings.expire
      Settings
    end
end

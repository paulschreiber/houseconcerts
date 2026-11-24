require "test_helper"

class SettingsTest < ActiveSupport::TestCase
  test "reads the defaults when nothing is stored" do
    assert_equal Defaults.show.max_seats, Settings.show.max_seats
    assert_equal Defaults.site_name, Settings.site_name
    assert_equal Defaults.organization.domain, Settings.organization.domain
  end

  test "a stored value replaces the default, as the default's type" do
    SettingValue.create!(key: "show.max_seats", value: "6")
    SettingValue.create!(key: "site_name", value: "Jane’s Concerts")
    SettingValue.create!(key: "organization.confirms_from_email", value: "hello")

    assert_equal 6, Settings.show.max_seats
    assert_equal "Jane’s Concerts", Settings.site_name
    assert_equal "hello", Settings.organization.confirms_from_email
    assert_equal Defaults.organization.confirms_from_name, Settings.organization.confirms_from_name
    assert_equal Defaults.show.duration, Settings.show.duration
  end

  test "the defaults stay as they were" do
    original = Defaults.show.max_seats
    SettingValue.create!(key: "show.max_seats", value: "6")

    assert_equal 6, Settings.show.max_seats
    assert_equal original, Defaults.show.max_seats
  end

  test "ignores a stored value for a setting that can't be changed" do
    SettingValue.new(key: "organization.domain", value: "evil.example.org").save!(validate: false)

    assert_equal Defaults.organization.domain, Settings.organization.domain
  end

  test "casts a number strictly" do
    assert_equal 12, Settings.cast("show.max_seats", "12")
    assert_equal "12", Settings.cast("site_name", 12)
    [ " 5", "5.5", "1_0", "" ].each do |text|
      assert_raises(ArgumentError, text.inspect) { Settings.cast("show.max_seats", text) }
    end
  end

  test "an unknown setting raises" do
    assert_raises(KeyError) { Settings.nonexistent }
  end

  test "saving a value changes the settings at once, and deleting it restores the default" do
    assert_equal Defaults.show.max_seats, Settings.show.max_seats

    value = SettingValue.create!(key: "show.max_seats", value: "7")
    assert_equal 7, Settings.show.max_seats

    value.update!(value: "8")
    assert_equal 8, Settings.show.max_seats

    value.destroy
    assert_equal Defaults.show.max_seats, Settings.show.max_seats
  end

  test "reads the stored values from the cache, and a save clears it" do
    cache = ActiveSupport::Cache::MemoryStore.new
    with_stubbed(Rails, :cache, -> { cache }) do
      SettingValue.create!(key: "show.max_seats", value: "7")
      assert_equal 7, Settings.show.max_seats
      assert_equal({ "show.max_seats" => "7" }, cache.read(Settings::CACHE_KEY))

      SettingValue.find_by!(key: "show.max_seats").update!(value: "9")
      assert_nil cache.read(Settings::CACHE_KEY)
      assert_equal 9, Settings.show.max_seats
    end
  end
end

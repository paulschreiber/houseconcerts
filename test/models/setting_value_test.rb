require "test_helper"

class SettingValueTest < ActiveSupport::TestCase
  test "accepts an editable setting" do
    assert_predicate SettingValue.new(key: "show.max_seats", value: "5"), :valid?
  end

  test "rejects a setting that can't be changed or doesn't exist" do
    %w[admin_prefix organization.domain storage_service show.min_seats nonsense].each do |key|
      value = SettingValue.new(key:, value: "x")

      assert_not value.valid?, key
      assert_includes value.errors.attribute_names, :key
    end
  end

  test "rejects a value that doesn't fit the setting's type" do
    value = SettingValue.new(key: "show.max_seats", value: "many")

    assert_not value.valid?
    assert_includes value.errors.attribute_names, :value
  end

  test "rejects a number with underscores or a fraction" do
    %w[1_0 5.5 0x10].each do |text|
      assert_not SettingValue.new(key: "show.max_seats", value: text).valid?, text.inspect
    end
  end

  test "accepts a blank value for a text setting" do
    assert_predicate SettingValue.new(key: "google_analytics_id", value: ""), :valid?
  end

  test "requires a value" do
    assert_not SettingValue.new(key: "site_name", value: nil).valid?
  end

  test "has one value per setting" do
    SettingValue.create!(key: "site_name", value: "A")

    assert_not SettingValue.new(key: "site_name", value: "B").valid?
  end
end

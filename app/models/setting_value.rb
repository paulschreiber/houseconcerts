# A setting an admin changed from its default (see Settings), stored by its
# dotted key, such as "show.max_seats". Only the settings in Settings::EDITABLE
# can be stored, and only values that differ from the default need to be.
class SettingValue < ApplicationRecord
  validates :key, presence: true, uniqueness: true, inclusion: { in: Settings::EDITABLE }
  validates :value, exclusion: { in: [ nil ] }
  validate :value_matches_default_type

  after_commit -> { Settings.expire }

  private

    def value_matches_default_type
      return unless Settings::EDITABLE.include?(key) && !value.nil?

      Settings.cast(key, value)
    rescue ArgumentError
      errors.add(:value, :invalid)
    end
end

module ModelCleaners
  extend ActiveSupport::Concern

  included do
    # Before validation, so length checks count what's stored; again before
    # saving, for a save that skips validation.
    before_validation :clean_variables
    before_save :clean_variables
  end

  # Cleans the string attributes being saved (see TextCleaner): trimmed, line
  # breaks stored as \n (browsers send a textarea's as \r\n), and invisible
  # characters removed.
  def clean_variables
    changed_attribute_names_to_save.each do |a|
      value = self[a]
      self[a] = TextCleaner.clean(value) if value.is_a?(String)
    end
  end

  def upcase_province_and_country
    self.province = province.to_s.upcase if respond_to?(:province)
    self.country = country.to_s.upcase if respond_to?(:country)
  end
end

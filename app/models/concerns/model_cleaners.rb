module ModelCleaners
  extend ActiveSupport::Concern

  included do
    # Before validation, so length checks count what's stored; again before
    # saving, for a save that skips validation.
    before_validation :clean_variables
    before_save :clean_variables
  end

  # Trims the string attributes being saved and stores their line breaks as
  # \n (browsers send a textarea's as \r\n). Text is otherwise stored as
  # typed, markup included: views escape it.
  def clean_variables
    changed_attribute_names_to_save.each do |a|
      next if self[a].frozen?
      next unless self[a].is_a?(String)

      self[a] = self[a].strip.gsub("\r\n", "\n")
    end
  end

  def upcase_province_and_country
    self.province = province.to_s.upcase if respond_to?(:province)
    self.country = country.to_s.upcase if respond_to?(:country)
  end
end

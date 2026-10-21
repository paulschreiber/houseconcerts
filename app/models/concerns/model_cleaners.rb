module ModelCleaners
  extend ActiveSupport::Concern

  included do
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

  def should_generate_new_friendly_id?
    name_changed? || super
  end

  def name_slug_candidates
    cleaned_name = name.to_s.gsub(" and", "")

    2.upto(100).inject([ cleaned_name ]) { |a, e| a << format("%<name>s %<counter>d", name: cleaned_name, counter: e) }
  end
end

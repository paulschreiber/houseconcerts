module ModelCleaners
  extend ActiveSupport::Concern

  included do
    before_save :clean_variables
  end

  def clean_variables
    attributes.each_key do |a|
      next if self[a].frozen?
      next unless self[a].is_a?(String)

      # remove whitespace
      self[a].strip! if self[a].respond_to? :strip!

      # remove HTML
      self[a] = ActionView::Base.full_sanitizer.sanitize(self[a])
    end
  end

  def downcase_email
    self.email = email.to_s.downcase if respond_to?(:email)
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

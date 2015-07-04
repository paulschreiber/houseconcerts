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

  def update_slug
    self.slug = name.to_url
  end

  def downcase_email
    self.email = email.to_s.downcase if self.respond_to?(:email)
  end
end
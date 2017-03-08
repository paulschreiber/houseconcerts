module NameRules
  extend ActiveSupport::Concern

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def email_address_with_name
    return unless email.present?
    if full_name.present?
      "\"#{full_name}\" <#{email}>"
    else
      email
    end
  end
end

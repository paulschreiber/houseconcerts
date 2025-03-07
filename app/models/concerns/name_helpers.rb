module NameHelpers
  extend ActiveSupport::Concern

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def email_address_with_name
    return if email.blank?

    if full_name.present?
      "\"#{full_name}\" <#{email}>"
    else
      email
    end
  end
end

module NameHelpers
  extend ActiveSupport::Concern

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def email_address_with_name
    return if email.blank?

    ActionMailer::Base.email_address_with_name(email, full_name)
  end
end

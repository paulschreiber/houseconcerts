class ApplicationMailer < ActionMailer::Base
  default from: HC_CONFIG.invites_from
  layout "mailer"

  SEND_METHOD = :smtp

  def delivery_method
    if Rails.env.development?
      :letter_opener
    elsif SEND_METHOD == :sendmail
      :sendmail
    else
      :smtp
    end
  end

  def delivery_options
    if Rails.env.development?
      {}
    elsif SEND_METHOD == :smtp
      {
        user_name: HC_CONFIG.amazon_username,
        password: HC_CONFIG.amazon_password,
        address: HC_CONFIG.amazon_server,
        port: 587
      }
    end
  end
end

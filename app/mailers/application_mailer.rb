class ApplicationMailer < ActionMailer::Base
  default from: Settings.invites_from
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
        user_name: Rails.application.credentials.amazon.username,
        password: Rails.application.credentials.amazon.password,
        address: Rails.application.credentials.amazon.server,
        port: 587
      }
    end
  end
end

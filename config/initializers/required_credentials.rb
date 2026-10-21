# Amazon SES and (if used) Twilio credentials are only ever consumed in
# production (see config/environments/production.rb and SendTextMessage) --
# development uses letter_opener and logs texts instead. Fail loudly at boot
# if any are missing here, rather than discovering it later as a mailer
# crash or a failed reminder.
Rails.application.config.after_initialize do
  AssertRequiredCredentials.call if Rails.env.production?
end

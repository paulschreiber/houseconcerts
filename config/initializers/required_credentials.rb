# Twilio and Amazon SES credentials are only ever consumed in production
# (see TextMessagesController and config/environments/production.rb) --
# development uses letter_opener and test stubs Twilio via ENV, so neither
# touches these. Fail loudly at boot if either is missing here, rather than
# discovering it later as a silently rejected SMS webhook or a mailer crash.
Rails.application.config.after_initialize do
  AssertRequiredCredentials.call if Rails.env.production?
end

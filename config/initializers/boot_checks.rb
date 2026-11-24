# Fail loudly in production if the app can't boot properly (see BootChecks).
# Development uses letter_opener and the placeholder settings, and the tests set
# their own.
Rails.application.config.after_initialize do
  BootChecks.call if Rails.env.production?
end

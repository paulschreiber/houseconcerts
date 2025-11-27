source "https://rubygems.org"

ruby "3.3.8"

gem "mysql2"
gem "rails", "~> 8"

gem "dartsass-rails"
gem "propshaft"
gem "stimulus-rails"
gem "turbo-rails"

gem "solid_cable"
gem "solid_cache"
gem "solid_queue"

gem "bootsnap", require: false
gem "puma"
gem "thruster", require: false

gem "capistrano"
gem "capistrano-bundler"
gem "capistrano-passenger"
gem "capistrano-rails"

gem "net-smtp"

gem "carmen"
gem "config"
gem "default_value_for"
gem "devise"
gem "friendly_id"
gem "humanize"
gem "icalendar"
gem "redcarpet"
gem "twilio-ruby"
gem "validates_timeliness"
gem "validate_url"
gem "validation_kit"

gem "jbuilder"

group :production do
  gem "cloudflare-rails"
  gem "dalli"
end

group :development, :test do
  gem "brakeman", require: false
  gem "debug", platforms: %i[ mri mswin ], require: "debug/prelude"
end

group :development do
  gem "letter_opener"
  gem "rubocop", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rubocop-rake", require: false
  gem "ruby-lsp"
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end

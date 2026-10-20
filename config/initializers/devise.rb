# Settings that differ from Devise's defaults. The full list of options is in
# the gem's lib/generators/templates/devise.rb.
Devise.setup do |config|
  config.mailer_sender = ->(_mapping) { ActionMailer::Base.email_address_with_name("#{Settings.confirms_from_email}@#{Settings.domain}", Settings.confirms_from_name) }

  require "devise/orm/active_record"

  # Turbo submits the sign-in form via fetch (sending X-Requested-With), so
  # leaving this true makes Devise short-circuit to a bare 401 with no flash
  # message instead of re-rendering the form with the "invalid" alert.
  config.http_authenticatable_on_xhr = false

  # Password recovery behaves the same whether or not the email address is
  # an admin's.
  config.paranoid = true

  # The bcrypt cost; 1 keeps the test suite fast.
  config.stretches = Rails.env.test? ? 1 : 10

  # Email the old address when an admin's email changes, so a stolen session
  # can't quietly move an account to an attacker's address.
  config.send_email_changed_notification = true

  # Matches timeout_in: a remember-me cookie skips the inactivity timeout, so a
  # longer remember_for would keep an admin signed in past it.
  config.remember_for = 1.week

  config.password_length = 8..72

  # How long an admin can be inactive before signing in again.
  config.timeout_in = 1.week

  # Turbo requires 4xx/3xx status codes to render form-submission responses
  # without a redirect (a plain 200 re-render, Devise's old default, is
  # silently dropped instead of showing the "invalid password" flash).
  config.responder.error_status = :unprocessable_entity
  config.responder.redirect_status = :see_other
end

# Remember browsers admins sign in from; see AdminTrustedDevice.
Warden::Manager.after_authentication do |record, warden, options|
  AdminTrustedDevice.remember(ActionDispatch::Request.new(warden.env), record) if options[:scope] == :admin
end

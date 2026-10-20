# frozen_string_literal: true

WebAuthn.configure do |config|
  config.rp_name = Settings.site_name

  # This value needs to match `window.location.origin` evaluated by
  # the User Agent during registration and authentication ceremonies.
  if Rails.env.production?
    config.rp_id = Settings.domain
    config.allowed_origins = [ "https://#{Settings.domain}" ]
  else
    config.rp_id = "localhost"
    config.allowed_origins = [ "http://localhost:3000" ]
  end
end

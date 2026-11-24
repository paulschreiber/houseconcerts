# frozen_string_literal: true

WebAuthn.configure do |config|
  # This value needs to match `window.location.origin` evaluated by
  # the User Agent during registration and authentication ceremonies.
  if Rails.env.production?
    config.rp_id = Defaults.organization.domain
    config.allowed_origins = [ "https://#{Defaults.organization.domain}" ]
  else
    config.rp_id = "localhost"
    config.allowed_origins = [ "http://localhost:3000" ]
  end
end

# The relying party name is the site name, which is a setting, so it's read when
# a passkey is registered rather than when the app boots. Prepended because
# WebAuthn::RelyingParty only takes a fixed string (webauthn 3.5.1).
module RelyingPartySiteName
  def name
    Settings.site_name
  end
end

WebAuthn::RelyingParty.prepend(RelyingPartySiteName)

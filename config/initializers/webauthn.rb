# frozen_string_literal: true

WebAuthn.configure do |config|
  config.rp_name = Settings.site_name

  # This value needs to match `window.location.origin` evaluated by
  # the User Agent during registration and authentication ceremonies.
  if Rails.env.production?
    config.rp_id = Settings.site_hostname
    config.allowed_origins = [ "https://#{Settings.site_hostname}" ]
  else
    config.rp_id = "localhost"
    config.allowed_origins = [ "http://localhost:3000" ]
  end

  # Optionally configure a client timeout hint, in milliseconds.
  # This hint specifies how long the browser should wait for any
  # interaction with the user.
  # This hint may be overridden by the browser.
  # https://www.w3.org/TR/webauthn/#dom-publickeycredentialcreationoptions-timeout
  # config.credential_options_timeout = 120_000

  # Configure preferred binary-to-text encoding scheme. This should match the encoding scheme
  # used in your client-side (user agent) code before sending the credential to the server.
  # Supported values: `:base64url` (default), `:base64` or `false` to disable all encoding.
  #
  # config.encoding = :base64url

  # Possible values: "ES256", "ES384", "ES512", "PS256", "PS384", "PS512", "RS256", "RS384", "RS512", "RS1"
  # Default: ["ES256", "PS256", "RS256"]
  #
  # config.algorithms << "ES384"
end

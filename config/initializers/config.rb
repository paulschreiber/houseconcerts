app_keys = YAML.load_file("#{Rails.root}/config/application.yml", permitted_classes: [Symbol, OpenStruct])
HC_CONFIG = YAML.load_file("#{Rails.root}/config/settings.yml", permitted_classes: [Symbol, OpenStruct])
HC_CONFIG.facebook_app_secret = app_keys.facebook_app_secret
HC_CONFIG.amazon_username = app_keys.amazon_username
HC_CONFIG.amazon_password = app_keys.amazon_password
HC_CONFIG.twilio_account_sid = app_keys.twilio_account_sid
HC_CONFIG.twilio_auth_token = app_keys.twilio_auth_token
HC_CONFIG.twilio_sms_sender = app_keys.twilio_sms_sender

ActionMailer::Base.add_delivery_method :ses, AWS::SES::Base,
  :access_key_id     => HC_CONFIG.amazon_username,
  :secret_access_key => HC_CONFIG.amazon_password,
  :signature_version => 4

Rails.application.configure do
  config.action_mailer.default_url_options = { host: HC_CONFIG.hostname }
end
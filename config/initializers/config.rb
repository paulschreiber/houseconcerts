app_keys = YAML.load_file("#{Rails.root}/config/application.yml")

HC_CONFIG = YAML.load_file("#{Rails.root}/config/settings.yml")
HC_CONFIG.facebook_app_secret = app_keys.facebook_app_secret
HC_CONFIG.mandrill_username = app_keys.mandrill_username
HC_CONFIG.mandrill_api_key = app_keys.mandrill_api_key
HC_CONFIG.google_username = app_keys.google_username
HC_CONFIG.google_password = app_keys.google_password
HC_CONFIG.amazon_username = app_keys.amazon_username
HC_CONFIG.amazon_password = app_keys.amazon_password
HC_CONFIG.twilio_account_sid = app_keys.twilio_account_sid
HC_CONFIG.twilio_auth_token = app_keys.twilio_auth_token
HC_CONFIG.twilio_sms_sender = app_keys.twilio_sms_sender

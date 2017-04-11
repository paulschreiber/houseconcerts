app_keys = YAML.load_file("#{Rails.root}/config/application.yml")

HC_CONFIG = YAML.load_file("#{Rails.root}/config/settings.yml")
HC_CONFIG.facebook_app_secret = app_keys.facebook_app_secret
HC_CONFIG.mandrill_username = app_keys.mandrill_username
HC_CONFIG.mandrill_api_key = app_keys.mandrill_api_key
HC_CONFIG.google_username = app_keys.google_username
HC_CONFIG.google_password = app_keys.google_password
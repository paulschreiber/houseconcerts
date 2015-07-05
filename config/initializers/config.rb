app_keys = YAML.load_file("#{Rails.root}/config/application.yml")

HC_CONFIG = YAML.load_file("#{Rails.root}/config/settings.yml")
HC_CONFIG.facebook_app_secret = app_keys.facebook_app_secret

Config.setup do |config|
  # Defaults is the YAML settings. Settings (app/models/settings.rb) lays the
  # values an admin changed over them. Anything read while the app boots
  # (routes, initializers, production.rb) reads Defaults, since the database
  # isn't available yet.
  config.const_name = "Defaults"

  # Raise instead of silently returning nil when an undefined setting is
  # referenced.
  config.fail_on_missing = true
end

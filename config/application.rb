require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Houseconcerts
  class Application < Rails::Application
    # Rails.autoloaders.log!

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    config.time_zone = "Eastern Time (US & Canada)"
    config.i18n.load_path += Rails.root.glob("config/locales/**/*.{rb,yml}")

    # Lets a model's locale file set its own full_messages format (see
    # config/locales/models/*/en.yml).
    config.active_model.i18n_customize_full_message = true

    # Lets the en-admin locale (see Madmin::ApplicationController) override only
    # the messages it words differently and use the en ones for the rest.
    config.i18n.fallbacks = true

    # Only photo sizes (Active Storage variants) are served; config/routes.rb
    # draws just their route. Active Storage's own routes would serve the
    # stored photo itself to anyone with a photo size's URL (both use the same
    # signed blob id), and accept direct uploads from anyone. Photo sizes are
    # served through the app, so their URLs stay on the site's own domain: the
    # content security policy's img-src 'self' allows them, and Cloudflare
    # caches them.
    config.active_storage.draw_routes = false

    # Gate Mission Control - Jobs behind the existing admin login instead of
    # its default HTTP Basic auth.
    config.mission_control.jobs.base_controller_class = "AdminController"
    config.mission_control.jobs.http_basic_auth_enabled = false
  end
end

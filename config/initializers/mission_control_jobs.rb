# dartsass-rails only compiles scss files listed here (default: just
# application.scss), so mission_control_custom.scss needs its own entry.
Rails.application.config.dartsass.builds["mission_control_custom.scss"] = "mission_control_custom.css"

# Use Mission Control's own config hook for the "Back to main app" link,
# rather than hardcoding the path in the overridden application_selection
# partial (still overridden, but only for the header it has no hook for).
MissionControl::Jobs.back_to_main_app_path = "/#{Settings.admin_prefix}"

# The admin sidebar (madmin/application/_navigation, rendered in the
# overridden application_selection partial) uses Madmin's nav_link_to and the
# app's *_path helpers. Mission Control's own delegates to the app's routes
# (HostRouteHelpers) go through main_app, which adds its server_id default
# URL option to every link (/backstage?server_id=async), so the sidebar gets
# its own that use the app's routes directly.
module MissionControlAdminPaths; end

ActiveSupport.on_load(:after_routes_loaded) do
  app_routes = Rails.application.routes
  names = app_routes.named_routes.helper_names.grep(/_path\z/) - MissionControl::Jobs::Engine.routes.named_routes.helper_names
  names.each do |name|
    MissionControlAdminPaths.define_method(name) { |*args| app_routes.url_helpers.public_send(name, *args) }
  end
end

Rails.application.config.to_prepare do
  MissionControl::Jobs::ApplicationController.helper Madmin::NavHelper, MissionControlAdminPaths
end

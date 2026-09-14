# dartsass-rails only compiles scss files listed here (default: just
# application.scss), so mission_control_custom.scss needs its own entry.
Rails.application.config.dartsass.builds["mission_control_custom.scss"] = "mission_control_custom.css"

# Use Mission Control's own config hook for the "Back to main app" link,
# rather than hardcoding the path in the overridden application_selection
# partial (still overridden, but only for the header it has no hook for).
MissionControl::Jobs.back_to_main_app_path = "/#{Settings.admin_prefix}"

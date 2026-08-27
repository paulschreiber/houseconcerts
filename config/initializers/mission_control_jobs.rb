# dartsass-rails only compiles scss files listed here (default: just
# application.scss), so mission_control_custom.scss needs its own entry.
Rails.application.config.dartsass.builds["mission_control_custom.scss"] = "mission_control_custom.css"

Madmin.stylesheets << "madmin_custom"
Madmin.site_name = Settings.site_name

# dartsass-rails only compiles scss files listed here (default: just
# application.scss), so madmin_custom.scss needs its own entry.
Rails.application.config.dartsass.builds["madmin_custom.scss"] = "madmin_custom.css"

# Sidebar order: Artists, Shows, divider, People, RSVPs, divider, Venues, Venue Groups.
# (positions set per-resource via `menu position: N`; these are the two dividers.)
Madmin.menu.before_render do
  add label: "divider-1", position: 25
  add label: "divider-2", position: 45
end

# Hide id/timestamp columns everywhere unless a resource explicitly opts back in
# (e.g. `attribute :created_at, show: true`).
module HidesIdAndTimestampsByDefault
  HIDDEN_BY_DEFAULT = %i[id created_at updated_at].freeze

  def visible?(action)
    return options.fetch(action.to_sym, false) if HIDDEN_BY_DEFAULT.include?(attribute_name)

    super
  end
end

Madmin::Field.prepend(HidesIdAndTimestampsByDefault)

# Madmin pages load their own importmap, which only includes Stimulus
# controllers from app/javascript/madmin/controllers. Pin the app's
# disable-on-submit controller there too, so the batch-action buttons
# (ShowResource.disable_on_submit) actually disable on submit.
Madmin.importmap.pin "controllers/disable_on_submit_controller", to: "controllers/disable_on_submit_controller.js"

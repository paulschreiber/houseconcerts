Madmin.stylesheets << "madmin_custom"
Madmin.site_name = Settings.site_name

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

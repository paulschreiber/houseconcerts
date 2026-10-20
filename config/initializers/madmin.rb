Madmin.stylesheets << "madmin_custom"
Madmin.site_name = Settings.site_name

# Madmin pages use Madmin's own importmap, not the app's. The passkeys page
# (Admins::PasskeysController renders in Madmin's layout) needs devise-webauthn's
# JavaScript to create a passkey.
Madmin.importmap.pin "devise/webauthn", to: "devise/webauthn.js"

# dartsass-rails only compiles scss files listed here (default: just
# application.scss), so madmin_custom.scss needs its own entry.
Rails.application.config.dartsass.builds["madmin_custom.scss"] = "madmin_custom.css"

# Sidebar order: Artists, Shows, divider, People, RSVPs, divider, Venues, Venue Groups.
# (positions set per-resource via `menu position: N`; these are the two dividers.)
Madmin.menu.before_render do
  add label: "divider-1", position: 25
  add label: "divider-2", position: 45
end

# App-specific changes to Madmin's own classes, prepended below.
module MadminPatches
  # Which columns and fields Madmin shows:
  # - id and timestamps are hidden everywhere unless a resource explicitly opts
  #   back in (e.g. `attribute :created_at, show: true`).
  # - An attribute's `index_scopes:` option limits the index pages that show
  #   its column to the given scopes (Current.admin_scope; nil is the unscoped
  #   list), e.g. `index_scopes: %w[next_show_attendees]`. Without the option,
  #   the column shows on every scope.
  module FieldVisibility
    HIDDEN_BY_DEFAULT = %i[id created_at updated_at].freeze

    def visible?(action)
      action = action.to_sym
      return false if action == :index && options[:index_scopes]&.exclude?(Current.admin_scope)
      return options.fetch(action, false) if HIDDEN_BY_DEFAULT.include?(attribute_name)

      super
    end
  end

  # Display names (the edit page's title and heading) come from the saved
  # record: after a failed save, Madmin re-renders the edit page with the
  # record as edited, which could have a blank name or no show. Each resource
  # defines its own display_name, so inherited puts this module in front of
  # each one as it's defined.
  module SavedDisplayName
    def inherited(base)
      super
      base.singleton_class.prepend(SavedDisplayName)
    end

    def display_name(record)
      record = record.class.find_by(id: record.id) || record if record.persisted? && record.changed?
      super
    end
  end
end

Madmin::Field.prepend(MadminPatches::FieldVisibility)
ActiveSupport.on_load(:madmin_resource) { singleton_class.prepend(MadminPatches::SavedDisplayName) }

# Fields and resources that change with the index scope or the action (see
# FieldVisibility and ShortDateTimeField's index_label) read them from Current.
# An unknown scope is left out, since Madmin shows the unscoped list for it.
ActiveSupport.on_load(:madmin_resource_controller) do
  before_action do
    scope = valid_scope
    Current.admin_scope = scope unless scope == :all
    Current.admin_action = action_name
  end
end

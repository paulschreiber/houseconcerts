Madmin.stylesheets << "madmin_custom"
Madmin.site_name = Settings.site_name

# Madmin pages use Madmin's own importmap, not the app's. The passkeys page
# (Admins::PasskeysController renders in Madmin's layout) needs devise-webauthn's
# JavaScript to create a passkey.
Madmin.importmap.pin "devise/webauthn", to: "devise/webauthn.js"

# dartsass-rails only compiles scss files listed here (default: just
# application.scss), so madmin_custom.scss needs its own entry.
Rails.application.config.dartsass.builds["madmin_custom.scss"] = "madmin_custom.css"

# Sidebar order: Artists, Shows, Invites, divider, People, RSVPs, divider, Venues, Venue Groups.
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

  # Display names (the edit page's title and heading) and delete confirmations
  # come from the saved record: after a failed save, Madmin re-renders the edit
  # page with the record as edited, which could have a blank name or no show.
  # Resources define their own display_name (and RSVPResource its own
  # delete_confirmation), so inherited puts this module in front of each one
  # as it's defined.
  module SavedDisplayName
    def inherited(base)
      super
      base.singleton_class.prepend(SavedDisplayName)
    end

    def display_name(record)
      super(saved_record(record))
    end

    def delete_confirmation(record)
      super(saved_record(record))
    end

    private

      def saved_record(record)
        return record unless record.persisted? && record.changed?

        record.class.find_by(id: record.id) || record
      end
  end

  # Delete confirmations read "the person Jane Smith", not "the Person Jane
  # Smith". Mirrors madmin 3.4.1's Resource.delete_confirmation, but lowercases
  # %{resource}; recheck it when upgrading Madmin.
  module DeleteConfirmation
    def delete_confirmation(record)
      I18n.t("madmin.resources.#{model.model_name.i18n_key}.confirmations.delete",
             default: :"madmin.confirmations.delete",
             resource: friendly_name.downcase,
             name: display_name(record))
    end
  end
end

Madmin::Field.prepend(MadminPatches::FieldVisibility)
ActiveSupport.on_load(:madmin_resource) do
  singleton_class.prepend(MadminPatches::SavedDisplayName)
  singleton_class.prepend(MadminPatches::DeleteConfirmation)
end

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

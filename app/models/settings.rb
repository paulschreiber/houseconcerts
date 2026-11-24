# The site's settings. Defaults, the config gem's constant, holds the defaults
# from config/settings.yml and its local overrides. Settings is those defaults
# with the values an admin changed (SettingValue) laid over them, so
# `Settings.show.max_seats` reads the same however the value is set.
#
# Only EDITABLE settings can be changed. The rest stay in the YAML files,
# because routes, Rack::Attack, config.hosts and Active Storage read them while
# the app boots, before the database is needed; those boot-time reads use
# Defaults directly.
#
# The changed values are cached (Rails.cache) and the merged settings are kept
# for the request or job (Current), so a request reads the cache once. Saving a
# SettingValue clears the cache; the hour's expiry only bounds a stale value if
# a read races a save.
module Settings
  CACHE_KEY = "settings/values".freeze

  EDITABLE = %w[
    site_name meta_description meta_keywords google_analytics_id
    default_country default_venue_group notify_rsvp guest_sign_off time_zone
    organization.invites_from_first_name organization.invites_from_last_name organization.invites_from_email
    organization.confirms_from_name organization.confirms_from_email
    venue.min_capacity venue.max_capacity
    show.min_price show.max_price show.max_seats show.waitlist_capacity show.overbook_seats
    show.duration show.arrival_minutes show.availability_cutoff_hours
    reminders.days_before reminders.hour
  ].freeze

  class << self
    # Reads go to the merged settings, which raise KeyError for an unknown one.
    def method_missing(name, *, &)
      current.public_send(name, *, &)
    end

    # Answered from the defaults, which have every key, so it needs no database.
    def respond_to_missing?(name, include_private = false)
      Defaults.respond_to?(name, include_private) || super
    end

    # A stored value as the type of the setting's default. Raises ArgumentError
    # when it doesn't fit, such as "abc" or " 5" for a number.
    def cast(key, value)
      default = Defaults.dig(*key.split(".").map(&:to_sym))
      return value.to_s unless default.is_a?(Integer)

      raise ArgumentError, "not a whole number: #{value.inspect}" unless value.to_s.match?(/\A-?\d+\z/)

      Integer(value, 10)
    end

    # The values an admin changed, by key, as stored (cached). The merged
    # settings need these too, but a caller that wants one value, such as
    # SiteTimeZone when each request starts, can read it without building them.
    def stored
      Rails.cache.fetch(CACHE_KEY, expires_in: 1.hour) { SettingValue.where(key: EDITABLE).pluck(:key, :value).to_h }
    end

    # Clears the cached values, and the merged settings kept for this request.
    def expire
      Rails.cache.delete(CACHE_KEY)
      Current.settings = nil
    end

    private

      def current
        Current.settings ||= build
      end

      def build
        merged = Defaults.to_h.deep_dup
        stored.each do |key, value|
          *parents, name = key.split(".").map(&:to_sym)
          (parents.empty? ? merged : merged.dig(*parents))[name] = cast(key, value)
        end
        Config::Options.new.tap do |settings|
          settings.add_source!(merged)
          settings.reload!
        end
      end
  end
end

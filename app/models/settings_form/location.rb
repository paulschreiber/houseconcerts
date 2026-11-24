class SettingsForm
  class Location < SettingsForm
    setting :default_country, "default_country"
    setting :default_venue_group, "default_venue_group", :integer
    # The zone as the select names it ("Pacific Time (US & Canada)"), whichever
    # way it was written (America/Los_Angeles is the same zone).
    def self.rails_zone_name(zone)
      found = ActiveSupport::TimeZone[zone.to_s]
      found ? ActiveSupport::TimeZone::MAPPING.key(found.tzinfo.name) || found.name : zone
    end

    setting :time_zone, "time_zone", from: ->(zone) { rails_zone_name(zone) }

    validate :country_exists
    validate :venue_group_exists
    validate :time_zone_exists

    private

      def country_exists
        errors.add(:default_country, :inclusion) unless Carmen::Country.coded(default_country.to_s)
      end

      def time_zone_exists
        errors.add(:time_zone, :inclusion) unless ActiveSupport::TimeZone[time_zone.to_s]
      end

      def venue_group_exists
        errors.add(:default_venue_group, :inclusion) unless VenueGroup.exists?(default_venue_group)
      end
  end
end

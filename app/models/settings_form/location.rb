class SettingsForm
  class Location < SettingsForm
    setting :default_country, "default_country"
    setting :default_venue_group, "default_venue_group", :integer

    validate :country_exists
    validate :venue_group_exists

    private

      def country_exists
        errors.add(:default_country, :inclusion) unless Carmen::Country.coded(default_country.to_s)
      end

      def venue_group_exists
        errors.add(:default_venue_group, :inclusion) unless VenueGroup.exists?(default_venue_group)
      end
  end
end

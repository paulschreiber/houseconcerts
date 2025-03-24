module Geography
  extend ActiveSupport::Concern

  def province_codes
    subregions = Carmen::Country.coded(Settings.default_country).subregions
    subregions = subregions.select { |s| s.type == "state" } if Settings.default_country == "US"
    subregions.map(&:code)
  end

  def country_codes
    Carmen::Country.all.collect(&:code)
  end
end

module Geography
  extend ActiveSupport::Concern
  include DefaultCountry

  def province_codes
    subregions = Carmen::Country.coded(default_country).subregions
    subregions = subregions.select { |s| s.type == "state" } if default_country == "US"
    subregions.map(&:code)
  end

  def country_codes
    Carmen::Country.all.collect(&:code)
  end
end

module Geography
  extend ActiveSupport::Concern

  def province_codes
    subregions = Carmen::Country.coded(HC_CONFIG.default_country).subregions
    subregions = subregions.select{|s| s.type == 'state'} if HC_CONFIG.default_country == "US"
    subregions.map{|s| s.code}
  end

  def country_codes
    Carmen::Country.all.collect(&:code)
  end
end
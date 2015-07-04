module Geography
  extend ActiveSupport::Concern

  def us_state_codes
    Carmen::Country.coded('US').subregions.map{|s| s.code if s.type == 'state'}.compact
  end

  def country_codes
    Carmen::Country.all.collect(&:code)
  end
end
class Venue < ActiveRecord::Base
  has_and_belongs_to_many :venue_groups
  has_many :shows

  before_save :update_slug

  validates :name, presence: true
  validates :address, presence: true
  validates :city, presence: true
  validates :province, inclusion: { in: lambda { |x| x.province_codes } }
  validates :postcode, postal_code: { country: HC_CONFIG.default_country }
  validates :country, inclusion: { in: lambda { |x| x.country_codes } }
  validates :capacity, presence: true, numericality: {
    only_integer: true,
    greater_than_or_equal_to: HC_CONFIG.venue.min_capacity,
    less_than_or_equal_to: HC_CONFIG.venue.max_capacity
  }

end

class Venue < ActiveRecord::Base
  include Geography
  extend FriendlyId
  friendly_id :name_slug_candidates, use: :slugged

  has_and_belongs_to_many :venue_groups
  has_many :shows

  before_save :upcase_province_and_country

  validates :name, presence: true
  validates :address, presence: true
  validates :city, presence: true
  validates :province, inclusion: { in: -> x { x.province_codes } }
  validates :postcode, postal_code: { country: HC_CONFIG.default_country }
  validates :country, inclusion: { in: -> x { x.country_codes } }
  validates :capacity, presence: true, numericality: {
    only_integer: true,
    greater_than_or_equal_to: HC_CONFIG.venue.min_capacity,
    less_than_or_equal_to: HC_CONFIG.venue.max_capacity
  }

  def province_name
    Carmen::Country.coded(HC_CONFIG.default_country).subregions.coded(province)
  end

  def location
    "#{city}, #{province_name}"
  end

  def full_address
    "#{address} · #{city}, #{province_name} #{postcode}"
  end

  # Shared renderer instance
  def markdown_renderer
    @renderer ||= Redcarpet::Markdown.new(Redcarpet::Render::HTML.new(hard_wrap: true))
  end

  def formatted_directions
    markdown_renderer.render(directions) if directions
  end

  def formatted_contact_info
    markdown_renderer.render(contact_info) if contact_info
  end
end

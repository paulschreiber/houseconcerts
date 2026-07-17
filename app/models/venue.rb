class Venue < ApplicationRecord
  include Geography
  extend FriendlyId

  friendly_id :name_slug_candidates, use: :slugged

  has_many :venue_group_venues, dependent: :destroy
  has_many :venue_groups, through: :venue_group_venues
  has_many :shows, dependent: :nullify

  before_save :upcase_province_and_country

  validates :name, presence: true
  validates :address, presence: true
  validates :city, presence: true
  validates :province, inclusion: { in: ->(record) { record.province_codes } }
  validates :postcode, postal_code: { country: Settings.default_country }
  validates :country, inclusion: { in: ->(record) { record.country_codes } }
  validates :capacity, presence: true, numericality: {
    only_integer: true,
    greater_than_or_equal_to: Settings.venue.min_capacity,
    less_than_or_equal_to: Settings.venue.max_capacity
  }

  def province_name
    Carmen::Country.coded(Settings.default_country).subregions.coded(province)
  end

  def location
    "#{city}, #{province_name}"
  end

  def full_address
    "#{address} · #{city}, #{province_name} #{postcode}"
  end

  def full_address_calendar
    "#{address} #{city}, #{province_name} #{postcode}"
  end

  # Shared renderer instance
  def markdown_renderer
    @markdown_renderer ||= Redcarpet::Markdown.new(Redcarpet::Render::HTML.new(hard_wrap: true))
  end

  def formatted_directions
    markdown_renderer.render(directions) if directions
  end

  def formatted_contact_info
    markdown_renderer.render(contact_info) if contact_info
  end
end

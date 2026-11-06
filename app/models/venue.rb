class Venue < ApplicationRecord
  include Geography
  extend FriendlyId

  friendly_id :name_slug_candidates, use: :slugged

  has_many :venue_group_venues, dependent: :delete_all
  has_many :venue_groups, through: :venue_group_venues
  has_many :shows, dependent: :restrict_with_error

  before_validation :upcase_province_and_country
  after_update :update_shows_availability, if: :saved_change_to_capacity?

  validates :name, presence: true
  validates :address, presence: true
  validates :city, presence: true
  validates :province, inclusion: { in: ->(record) { record.province_codes } }
  validates :postcode, postal_code: { country: Settings.default_country }
  validates :country, inclusion: { in: ->(record) { record.country_codes } }
  validates :capacity, presence: true, numericality: {
    allow_nil: true,
    only_integer: true,
    greater_than_or_equal_to: Settings.venue.min_capacity,
    less_than_or_equal_to: Settings.venue.max_capacity
  }

  # A rename changes the slug. Defined here, not in a concern included by
  # ApplicationRecord, so it takes precedence over friendly_id's Slugged
  # module, which only fills in a blank slug.
  def should_generate_new_friendly_id?
    name_changed? || super
  end

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
    "#{address}, #{city}, #{province_name} #{postcode}"
  end

  # Shared renderer instance
  def markdown_renderer
    @markdown_renderer ||= MarkdownRenderer.parser
  end

  def formatted_directions
    markdown_renderer.render(directions) if directions
  end

  def formatted_contact_info
    markdown_renderer.render(contact_info) if contact_info
  end

  private

    def update_shows_availability
      shows.upcoming.each(&:update_availability)
    end
end

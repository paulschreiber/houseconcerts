class Venue < ApplicationRecord
  # Redcarpet's safe_links_only allows the same schemes as SAFE_LINK except
  # tel:, so a phone number in a venue's contact info can't be a link.
  # Overriding #link replaces Redcarpet's own check, so this one has to
  # cover everything it did. As with Redcarpet's check, "/" and "#" need a
  # letter or digit next, which keeps out "//evil.example". Returning nil
  # leaves an unsafe link as escaped plain text.
  class MarkdownRenderer < Redcarpet::Render::HTML
    SAFE_LINK = %r{\A(?:(?:https?|ftp)://[[:alnum:]]|mailto:|tel:\+?[\d(]|[/#][[:alnum:]])}i

    def link(link, title, content)
      return unless link&.match?(SAFE_LINK)

      title_attribute = %( title="#{ERB::Util.html_escape(title)}") if title.present?
      %(<a href="#{ERB::Util.html_escape(link)}"#{title_attribute}>#{content}</a>)
    end
  end

  include Geography
  extend FriendlyId

  friendly_id :name_slug_candidates, use: :slugged

  has_many :venue_group_venues, dependent: :delete_all
  has_many :venue_groups, through: :venue_group_venues
  has_many :shows, dependent: :nullify

  before_validation :upcase_province_and_country

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
    @markdown_renderer ||= Redcarpet::Markdown.new(MarkdownRenderer.new(hard_wrap: true, escape_html: true, safe_links_only: true))
  end

  def formatted_directions
    markdown_renderer.render(directions) if directions
  end

  def formatted_contact_info
    markdown_renderer.render(contact_info) if contact_info
  end
end

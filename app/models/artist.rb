class Artist < ApplicationRecord
  extend FriendlyId

  friendly_id :name_slug_candidates, use: :slugged

  has_many :artist_shows, dependent: :delete_all
  has_many :shows, through: :artist_shows

  validates :name, presence: true
  validates :url, url: true, allow_blank: true

  def photo
    "photos/headshots/#{slug}.jpg"
  end

  def photo_url
    "#{Rails.application.routes.url_helpers.root_url}#{photo}"
  end
end

class Artist < ApplicationRecord
  extend FriendlyId

  friendly_id :name_slug_candidates, use: :slugged

  has_many :artist_shows, dependent: :destroy
  has_many :shows, through: :artist_shows

  validates :name, presence: true
  validates :url, url: true

  def photo
    "photos/headshots/#{slug}.jpg"
  end
end

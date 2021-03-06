class Artist < ApplicationRecord
  extend FriendlyId
  friendly_id :name_slug_candidates, use: :slugged

  has_and_belongs_to_many :shows

  validates :name, presence: true
  validates :url, url: true

  def photo
    "photos/headshots/#{slug}.jpg"
  end
end

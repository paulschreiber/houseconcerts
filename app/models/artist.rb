class Artist < ActiveRecord::Base
  has_and_belongs_to_many :shows

  before_save :update_slug

  validates :name, presence: true
  validates :url, url: true
end

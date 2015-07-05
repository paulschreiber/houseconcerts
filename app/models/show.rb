class Show < ActiveRecord::Base
  has_and_belongs_to_many :artists
  has_many :rsvps
  belongs_to :venue

  scope :confirmed, -> { where(status: HC_CONFIG.show.status[:confirmed]) }
  scope :upcoming, -> { where("start > ?", Time.now) }

  before_save :update_slug
end

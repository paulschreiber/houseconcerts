class Show < ActiveRecord::Base
  STATUS_CONFIRMED = 'G'

  has_and_belongs_to_many :artists
  has_many :rsvps
  belongs_to :venue

  scope :confirmed, -> { where(status: STATUS_CONFIRMED) }
  scope :upcoming, -> { where("start > ?", Time.now) }
end

class Show < ActiveRecord::Base
  has_and_belongs_to_many :artists
  has_many :rsvps
  belongs_to :venue

  scope :confirmed, -> { where(status: HC_CONFIG.show.status[:confirmed]) }
  scope :upcoming, -> { where("start > ?", Time.now) }

  before_save :update_slug

  validates :start, timeliness: { type: :datetime }
  validates :end, timeliness: { type: :datetime }
  validates :name, presence: true
  validates :status, inclusion: { in: HC_CONFIG.show.status.keys }
  validates :price, presence: true, numericality: {
    only_integer: true,
    greater_than_or_equal_to: HC_CONFIG.show.min_price,
    less_than_or_equal_to: HC_CONFIG.show.max_price
  }
  validates :venue, presence: true

end

class Show < ActiveRecord::Base
  extend FriendlyId
  friendly_id :name_slug_candidates, use: :slugged

  has_and_belongs_to_many :artists
  has_many :rsvps
  belongs_to :venue

  scope :confirmed, -> { where(status: HC_CONFIG.show.status[:confirmed]) }
  scope :upcoming, -> { where("start > ?", Time.now) }

  validates :start, timeliness: { type: :datetime }
  validates :end, timeliness: { type: :datetime, after: lambda{ |x| x.start } }
  validates :name, presence: true
  validates :status, inclusion: { in: HC_CONFIG.show.status.values }
  validates :price, presence: true, numericality: {
    only_integer: true,
    greater_than_or_equal_to: HC_CONFIG.show.min_price,
    less_than_or_equal_to: HC_CONFIG.show.max_price
  }
  validates :venue, presence: true


  # define .confirmed, .cancelled?, .unconfirmed? methods
  HC_CONFIG.show.status.keys.each do |key|
    define_method("#{key}?") { status == key }
  end

  def duration
    ((self.end - self.start)/60).to_i
  end

  def start_time
    self.start.strftime("%l %P").strip
  end

  def start_date
    self.start.strftime("%A, %B %e, %Y").strip
  end

end

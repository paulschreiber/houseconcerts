class Show < ActiveRecord::Base
  extend FriendlyId
  friendly_id :name_slug_candidates, use: :slugged

  has_and_belongs_to_many :artists
  has_many :rsvps
  belongs_to :venue

  scope :confirmed, -> { where(status: 'confirmed') }
  scope :occurred, -> { where(status: ['sold out', 'waitlisted', 'confirmed']) }
  scope :upcoming, -> { where('start > ?', Time.now).order(:start) }
  scope :past, -> { where('start < ?', Time.now) }

  validates :start, timeliness: { type: :datetime }
  validates :end, timeliness: { type: :datetime, after: ->x { x.start } }
  validates :name, presence: true
  validates :status, inclusion: { in: HC_CONFIG.show.status }
  validates :price, presence: true, numericality: {
    only_integer: true,
    greater_than_or_equal_to: HC_CONFIG.show.min_price,
    less_than_or_equal_to: HC_CONFIG.show.max_price
  }
  validates :venue, presence: true

  # define .confirmed?, .cancelled?, .unconfirmed?, .waitlisted?, .sold_out? methods
  HC_CONFIG.show.status.each do |value|
    define_method("#{value.gsub(' ', '_')}?") { status == value }
  end

  def duration
    (self.end - start).to_i
  end

  def start_time
    start.strftime('%l %P').strip
  end

  def start_date
    start.strftime('%A, %B %e, %Y').gsub('  ', ' ').strip
  end

  def start_date_short
    start.strftime('%b %e').gsub('  ', ' ').strip
  end

  def location
    venue.location if venue
  end
end

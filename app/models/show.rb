class Show < ApplicationRecord
  extend FriendlyId

  friendly_id :name_slug_candidates, use: :slugged

  has_many :artist_shows, dependent: :destroy
  has_many :artists, through: :artist_shows
  has_many :rsvps, dependent: :destroy
  belongs_to :venue

  before_validation :set_end_time

  enum :status, { confirmed: 0, unconfirmed: 1, cancelled: 2 }

  scope :occurred, -> { confirmed.where(start: ...Time.zone.now).order(:start) }
  scope :upcoming, -> { confirmed.where("start > ?", Time.zone.now).order(:start) }

  validates :start, timeliness: { type: :datetime }
  validates :end, timeliness: { type: :datetime, after: ->(record) { record.start } }
  validates :name, presence: true
  validates :price, presence: true, numericality: {
    only_integer: true,
    greater_than_or_equal_to: Settings.show.min_price,
    less_than_or_equal_to: Settings.show.max_price
  }
  validates :venue_id, inclusion: { in: ->(_) { Venue.all.collect(&:id) } }

  # TODO: ticket availability (sold out / waitlisted) is moving to its own column;
  # until that lands, no show can be sold out or waitlisted.
  def sold_out?
    false
  end

  def waitlisted?
    false
  end

  def attendees
    rsvps.where(confirmed: "yes", response: "yes")
  end

  def self.next
    upcoming.first
  end

  def next_show?
    Show.upcoming.first.id == id
  end

  def self.past
    occurred
  end

  def self.previous
    past.last
  end

  def duration
    (self.end - start).to_i
  end

  def day_of_week
    start.strftime("%A")
  end

  def start_time
    start&.strftime("%l:%M %P")&.strip
  end

  def start_date
    start.strftime("%A, %B %e, %Y").gsub("  ", " ").strip unless start.nil?
  end

  def start_date_short
    start.strftime("%B %e").gsub("  ", " ").strip unless start.nil?
  end

  def door_time
    (start - Settings.arrival_minutes.minutes) unless start.nil?
  end

  def arrival_range
    return if start.nil?

    earliest = door_time.strftime("%l:%M %P").strip
    latest = (start - 1.minute).strftime("%l:%M %P").strip
    "#{earliest} and #{latest}"
  end

  def occurred?
    start < Time.zone.now
  end

  def location
    venue&.location
  end

  def to_s
    "#{name} (#{start_date_short})"
  end

  def set_end_time
    self.end = start + Settings.show_duration.hours unless self.end
  end
end

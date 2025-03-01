class Show < ApplicationRecord
  extend FriendlyId
  friendly_id :name_slug_candidates, use: :slugged

  has_and_belongs_to_many :artists
  has_many :rsvps, dependent: :destroy
  belongs_to :venue

  before_validation :set_end_time

  scope :confirmed, -> { where(status: "confirmed") }
  scope :confirmed_or_full, -> { where(status: [ "sold out", "waitlisted", "confirmed" ]) }
  scope :occurred, -> { confirmed_or_full.where("start < ?", Time.zone.now).order(:start) }
  scope :upcoming, -> { confirmed_or_full.where("start > ?", Time.zone.now).order(:start) }

  validates :start, timeliness: { type: :datetime }
  validates :end, timeliness: { type: :datetime, after: lambda(&:start) }
  validates :name, presence: true
  validates :status, inclusion: { in: HC_CONFIG.show.status }
  validates :price, presence: true, numericality: {
    only_integer: true,
    greater_than_or_equal_to: HC_CONFIG.show.min_price,
    less_than_or_equal_to: HC_CONFIG.show.max_price
  }
  validates :venue_id, inclusion: { in: ->(_) { Venue.all.collect(&:id) } }

  # define .confirmed?, .cancelled?, .unconfirmed?, .waitlisted?, .sold_out? methods
  HC_CONFIG.show.status.each do |value|
    define_method("#{value.tr(' ', '_')}?") { status == value }

    # define .confirmed!, .cancelled!, .unconfirmed!, .waitlisted!, .sold_out! methods
    define_method("#{value.tr(' ', '_')}!") do
      update(status: value)
    end
  end

  def self.next
    upcoming.first
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
    (start - HC_CONFIG.arrival_minutes.minutes) unless start.nil?
  end

  def arrival_range
    return if start.nil?

    earliest = door_time.strftime("%l:%M %P").strip
    latest = (start - 1.minute).strftime("%l:%M %P").strip
    "#{earliest} and #{latest}"
  end

  def location
    venue&.location
  end

  def to_s
    "#{name} (#{start_date_short})"
  end

  def set_end_time
    self.end = start + HC_CONFIG.show_duration.hours unless self.end
  end
end

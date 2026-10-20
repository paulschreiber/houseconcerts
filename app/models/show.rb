class Show < ApplicationRecord
  extend FriendlyId

  friendly_id :name_slug_candidates, use: :slugged

  has_many :artist_shows, dependent: :delete_all
  has_many :artists, through: :artist_shows
  has_many :rsvps, dependent: :destroy
  has_many :batch_runs, dependent: :destroy
  belongs_to :venue

  before_validation :set_end_time
  before_update :reset_auto_remind, if: :will_save_change_to_start?

  enum :status, { confirmed: 0, unconfirmed: 1, cancelled: 2 }, default: :confirmed
  enum :availability, { available: 0, waitlisted: 1, sold_out: 2 }, default: :available

  scope :occurred, -> { confirmed.where(start: ...Time.zone.now).order(:start) }
  scope :upcoming, -> { confirmed.where("start > ?", Time.zone.now).order(:start) }

  # Upcoming shows whose reminder time has passed and that
  # ScheduledRemindersJob hasn't tried yet. Narrowed in SQL to shows starting
  # soon enough, then filtered on reminder_time.
  def self.reminders_due
    upcoming.where(auto_remind_attempted_at: nil)
            .where(start: ..(Settings.reminders.days_before + 1).days.from_now)
            .select { |show| show.reminder_time <= Time.zone.now }
  end

  validates :start, timeliness: { type: :datetime }
  validates :end, timeliness: { type: :datetime, after: ->(record) { record.start } }
  validates :name, presence: true
  validates :price, presence: true, numericality: {
    only_integer: true,
    greater_than_or_equal_to: Settings.show.min_price,
    less_than_or_equal_to: Settings.show.max_price
  }

  def attendees
    rsvps.attending
  end

  def self.next
    upcoming.first
  end

  def next_show?
    Show.next&.id == id
  end

  def self.past
    occurred
  end

  def self.previous
    past.last
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

  def doors
    (start - Settings.arrival_minutes.minutes) unless start.nil?
  end

  def door_time
    doors&.strftime("%l:%M %P")&.strip
  end

  def arrival_range
    return if start.nil?

    latest = (start - 1.minute).strftime("%l:%M %P").strip
    "#{door_time} and #{latest}"
  end

  def occurred?
    start < Time.zone.now
  end

  # Public RSVPs are only taken for confirmed shows that haven't happened yet.
  def accepting_rsvps?
    confirmed? && !occurred?
  end

  def location
    venue&.location
  end

  def can_confirm_rsvps?
    confirmed? && available?
  end

  def can_waitlist_rsvps?
    confirmed? && waitlisted?
  end

  def invites_sent?
    batch_runs.invite.delivered.exists?
  end

  # When reminders go out automatically: a fixed hour, a fixed number of
  # calendar days before the show (so it stays at that hour across a
  # daylight saving change).
  def reminder_time
    start&.days_ago(Settings.reminders.days_before)&.change(hour: Settings.reminders.hour)
  end

  def reminder_time_label
    reminder_time&.strftime("%a, %b %-d at %-l:%M %P")
  end

  # Reminders have been started (or cancelled) for the show's current date,
  # so ScheduledRemindersJob leaves it alone. A pending run doesn't count:
  # its fan-out never got enqueued, and starting it again resumes it.
  def reminders_handled?
    runs = batch_runs.remind.not_pending
    runs = runs.where(created_at: rescheduled_at..) if rescheduled_at
    runs.exists?
  end

  # ScheduledRemindersJob will still try this show's reminders.
  def auto_remind_pending?
    confirmed? && !occurred? && auto_remind_attempted_at.nil? && !reminders_handled?
  end

  # Whether ScheduledRemindersJob will send the show's reminders, shown on its
  # admin page, including beside a run from before the show was rescheduled.
  def auto_remind_note
    return "goes out automatically #{reminder_time_label}" if auto_remind_pending?

    "couldn’t start automatically" if auto_remind_attempted_at?
  end

  def to_s
    "#{name} (#{start_date_short})"
  end

  # The event's public name: the show's name followed by "house concert".
  def event_name
    "#{name} house concert"
  end

  def summary
    "#{name} (#{start&.to_date&.iso8601})"
  end

  def set_end_time
    self.end = start + Settings.show_duration.hours unless self.end
  end

  private

    # A new date gets its own reminders: the automatic attempt is reset, and
    # reminders sent before now no longer count (see reminders_handled?).
    # The attempt is always written, since ScheduledRemindersJob sets it
    # without updating any loaded copy of the show.
    def reset_auto_remind
      auto_remind_attempted_at_will_change!
      self.auto_remind_attempted_at = nil
      self.rescheduled_at = Time.current
    end
end

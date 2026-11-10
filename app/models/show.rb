class Show < ApplicationRecord
  extend FriendlyId

  friendly_id :name_slug_candidates, use: :slugged

  # In the order the artists were added, usually the headliner first.
  has_many :artist_shows, -> { order(:id) }, dependent: :delete_all, inverse_of: :show
  has_many :artists, through: :artist_shows
  has_many :rsvps, dependent: :destroy
  has_many :batch_runs, dependent: :destroy
  has_many :invite_messages, -> { order(:revision) }, dependent: :destroy, inverse_of: :show
  belongs_to :venue

  before_validation :set_end_time
  before_save :assign_availability, if: :will_save_change_to_venue_id?
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
    allow_nil: true,
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
    start&.strftime("%A, %B %-d, %Y")
  end

  def start_date_short
    start&.strftime("%B %-d")
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

  # Confirming sends the confirmation email, which needs a complete show.
  def can_confirm_rsvps?
    available? && complete?
  end

  # Ready for guest-facing emails and pages: confirmed, with at least one
  # artist. (Every saved show has a venue.)
  def complete?
    confirmed? && artists.any?
  end

  # Whether the show is full, has room on its waitlist, or is sold out follows
  # its RSVPs' seats (T) against the venue's capacity (C) and the waitlist
  # capacity (W): available below C, waitlisted from C, sold out from C + W.
  # Waitlisted seats count in T, so waitlisting an RSVP doesn't change the
  # state. Within Settings.show.availability_cutoff_hours of the start there's
  # no time to work a waitlist: a full show goes straight to sold out, and no
  # state goes back to a better one as seats free up.
  def computed_availability
    return availability unless confirmed? && start && !occurred?

    seats = rsvps.yes.sum(:seats_reserved)
    capacity = venue.capacity
    waitlist_limit = capacity + Settings.show.waitlist_capacity

    # After the cutoff, availability is no longer opened up: it stays as set
    # and can only change to sold out.
    if start <= Settings.show.availability_cutoff_hours.hours.from_now
      limit = waitlisted? ? waitlist_limit : capacity
      return seats >= limit ? "sold_out" : availability
    end

    # Before the cutoff, availability follows the seat counts alone.
    if seats >= waitlist_limit
      "sold_out"
    elsif seats >= capacity
      "waitlisted"
    else
      "available"
    end
  end

  # Saves the computed availability on a saved show, for when its RSVPs or
  # venue capacity change. It skips validations and callbacks, which have
  # nothing to say about it.
  def update_availability
    value = computed_availability
    update_columns(availability: value) unless value == availability # rubocop:disable Rails/SkipsModelValidations
  end

  def can_waitlist_rsvps?
    confirmed? && waitlisted?
  end

  # The highest revision of the invite, the only one that can be sent.
  def invite_message
    invite_messages.last
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

  # The name with the month and day, e.g. "Jane Smith (November 20)". The
  # admin notification emails use it implicitly, as <%= @show %>.
  def to_s
    "#{name} (#{start_date_short})"
  end

  # The show as an iCalendar event, for the calendar feed and the
  # confirmation email. Both use the same UID, so a calendar app that has the
  # show from one treats the other as the same event. The location defaults
  # to the public one, the city.
  def ical_event(url:, location: self.location)
    event = Icalendar::Event.new
    event.dtstart = Icalendar::Values::DateTime.new(start.utc, tzid: "UTC")
    event.dtend = Icalendar::Values::DateTime.new(self.end.utc, tzid: "UTC")
    event.summary = event_name
    event.location = location
    event.url = url
    event.uid = "event-#{slug}@#{Settings.domain}"
    event
  end

  # Events as a .ics file. METHOD:PUBLISH makes them plain events, not
  # meeting invitations whose replies would come back by email.
  def self.ical(events)
    calendar = Icalendar::Calendar.new
    events.each { |event| calendar.add_event(event) }
    calendar.publish
    calendar.to_ical
  end

  # The show's name and date, e.g. "jesse-terry-2026-11-20.ics". The name,
  # not the slug, which can end in a number that makes it unique.
  def ics_filename
    "#{name.parameterize}-#{start.to_date.iso8601}.ics"
  end

  # The event's public name: the show's name followed by "house concert".
  def event_name
    "#{name} house concert"
  end

  # The name with the full date, e.g. "Jane Smith (2026-11-20)", which sorts
  # and tells years apart in admin lists.
  def dated_name
    "#{name} (#{start&.to_date&.iso8601})"
  end

  # A show without an end lasts Settings.show_duration hours. Moving the start
  # moves the end too, keeping the show's length, unless the end was changed
  # as well.
  def set_end_time
    return unless start

    if self.end.nil?
      self.end = start + Settings.show_duration.hours
    elsif start_in_database && will_save_change_to_start? && !will_save_change_to_end?
      self.end += start - start_in_database
    end
  end

  private

    def assign_availability
      self.availability = computed_availability
    end

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

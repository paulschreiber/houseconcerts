class RSVP < ApplicationRecord
  # Madmin scope name.
  UNCONFIRMED_RSVPS_SCOPE = "unconfirmed_rsvps".freeze

  include ContactDetails
  include NameHelpers
  include NumberHelpers
  include IPAddress

  belongs_to :show

  enum :response, { no: 0, yes: 1 }, default: :no
  enum :confirmed, { unconfirmed: 0, waitlisted: 1, confirmed: 2 }, prefix: true, default: :unconfirmed

  alias confirmed? confirmed_confirmed?
  alias waitlisted? confirmed_waitlisted?
  alias unconfirmed? confirmed_unconfirmed?

  def attending?
    yes? && confirmed?
  end

  scope :attending, -> { yes.confirmed_confirmed }
  # Yes RSVPs still awaiting confirmation, including the waitlisted.
  scope :awaiting_confirmation, -> { yes.where(confirmed: %w[unconfirmed waitlisted]) }
  # Yes RSVPs holding seats: confirmed or unconfirmed, not waitlisted.
  scope :holding_seats, -> { yes.where.not(confirmed: "waitlisted") }

  before_validation :clear_seats_if_no
  before_save :set_ip_address
  before_save :update_confirmation_date
  before_save :update_cancellation_date
  before_save :update_response_date
  after_save :update_phone_number
  after_save -> { NotifyAdminOfRSVP.call(self) }

  attribute :uniqid, default: -> { SecureRandom.alphanumeric(Settings.uniqid_length) }

  validates :seats_reserved, numericality: {
    only_integer: true,
    greater_than_or_equal_to: Settings.show.min_seats,
    less_than_or_equal_to: Settings.show.max_seats
  }, unless: :no?
  validates :seats_used, absence: true, if: :no?
  validates :seats_used, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: Settings.show.max_seats_used
  }, allow_blank: true, if: :yes?
  validate :tickets_available?, unless: :no?, if: :requesting_more_seats?

  RSVP_NOTIFY_ATTRIBUTES = %w[first_name last_name seats_reserved response].freeze

  def update_confirmation_date
    return if !confirmed_changed? || !confirmed?

    self.confirmed_at = Time.zone.now
  end

  # A yes changing to no is a cancellation. A later yes clears it.
  def update_cancellation_date
    if response_changed?(from: "yes", to: "no")
      self.cancelled_at = Time.zone.now
    elsif response_changed?(to: "yes")
      self.cancelled_at = nil
    end
  end

  # When the RSVP was made or its response or seat count last changed,
  # including a cancellation or a switch back to yes.
  def update_response_date
    return unless new_record? || response_changed? || seats_reserved_changed?

    self.responded_at = Time.zone.now
  end

  def clear_seats_if_no
    return if yes?

    self.seats_reserved = 0
    self.seats_used = nil
    self.confirmed = "unconfirmed"
    # So a later re-RSVP "yes" gets its own fresh confirmation/waitlist
    # email instead of being silently skipped by the mailer's one-time
    # claim, which would otherwise still see this cancelled RSVP as
    # already emailed.
    self.confirmation_emailed_at = nil
    self.waitlist_emailed_at = nil
  end

  def tickets_available?
    return true unless show&.confirmed? && show.sold_out?

    errors.add(:show, "is sold out")
    false
  end

  # to_i: a blank or non-numeric seat count casts to nil, which the
  # numericality validation reports; comparing it would raise instead.
  def requesting_more_seats?
    new_record? || seats_reserved.to_i > seats_reserved_was.to_i
  end

  def confirm!
    return unless yes?

    self.confirmed = "confirmed"
    save
  end

  def waitlist!
    return unless yes?

    self.confirmed = "waitlisted"
    save
  end

  def cancel!
    return unless yes?

    self.response = "no"
    save
  end

  def person_exists?
    Person.exists?(email: email)
  end

  def create_person
    return if person_exists?

    Person.create(contact_attributes.merge(notes: "RSVPd for show #{show.slug}"))
  end

  def update_phone_number
    return if phone_number.blank?

    person = Person.find_by(email: email, phone_number: [ nil, "" ])
    person&.update(phone_number: phone_number)
  end

  def person
    Person.find_by(email: email)
  end

  def self.attended(emails)
    joins(:show).merge(Show.occurred).attending.where(email: emails)
  end

  # Maps each email to the ids of its attended RSVPs, so a caller with many
  # RSVPs to check (e.g. rendering a page of the admin index) can look up
  # each one against a single preloaded query instead of one query per row.
  def self.attended_before_map(emails)
    attended(emails).pluck(:email, :id).group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
  end

  def attended_before?
    return self.class.attended(email).where.not(id: id).exists? unless Current.attended_rsvp_ids_by_email

    Current.attended_rsvp_ids_by_email.fetch(email, []).any? { |attended_id| attended_id != id }
  end

  def confirm_opened?
    (Current.confirm_opens || Open.confirmations_opened([ self ])).include?([ Open.tag_for(show, "confirm"), email ])
  end

  # All emails that already have an RSVP for the given show, so a caller
  # with many people to check (e.g. rendering a page of the admin index)
  # can look them up against a single preloaded query instead of one query
  # per person.
  def self.rsvpd_emails(show)
    where(show: show).pluck(:email).to_set
  end

  def self.next_show
    RSVP.where(show: Show.next)
  end

  def can_confirm?
    !confirmed? && yes? && show&.can_confirm_rsvps?
  end

  def can_waitlist?
    unconfirmed? && yes? && show&.can_waitlist_rsvps?
  end

  def can_cancel?(next_show = Show.next)
    yes? && show.present? && show.id == next_show&.id && !show.occurred?
  end

  def self.next_show_attendees(show = Show.next)
    where(show:).attending
  end

  def self.unconfirmed_rsvps
    where(show: Show.next).awaiting_confirmation
  end

  def self.previous_show
    RSVP.where(show: Show.previous)
  end

  def self.previous_show_attendees
    where(show: Show.previous).attending
  end

  # A person who unsubscribed (or is bouncing/moved) still has a row in
  # people, so only an active person counts as a subscriber here -- someone
  # who previously unsubscribed and RSVPs again should show up as a
  # nonsubscriber, not be silently excluded.
  def self.nonsubscribers(show = Show.next)
    where(show:).yes.where.not(email: Person.active.select(:email))
  end

  def sms_reminder
    "Reminder: You have #{seats_reserved.humanize} #{'seat'.pluralize(seats_reserved)} for the #{show.name} show on #{show.start_date} at #{show.start_time}."
  end
end

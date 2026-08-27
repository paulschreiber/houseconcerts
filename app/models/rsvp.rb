class RSVP < ApplicationRecord
  include NameRules
  include NameHelpers
  include NumberHelpers
  include IPAddress

  belongs_to :show

  enum :response, { no: 0, yes: 1 }, default: :no
  enum :confirmed, { unconfirmed: 0, waitlisted: 1, yes: 2 }, prefix: true, default: :unconfirmed

  before_validation :clear_seats_if_no
  before_save :downcase_email
  before_save :set_ip_address
  before_save :update_confirmation_date
  after_save :update_phone_number
  after_save -> { NotifyAdminOfRSVP.call(self) }, unless: :confirmed?

  default_value_for :uniqid do
    SecureRandom.alphanumeric(8)
  end

  validates :first_name, presence: true, mixed_case: true, length: { minimum: 2 }, unless: :allowed_name_exception?
  validates :last_name, presence: true, mixed_case: true, length: { minimum: 2 }, unless: :allowed_name_exception?
  validates :email, email: true
  validates :phone_number, phone: { country: Settings.default_country, set: true }, allow_blank: true
  validates :postcode, postal_code: { country: Settings.default_country }, allow_blank: true
  validates :seats_reserved, numericality: {
    only_integer: true,
    greater_than_or_equal_to: Settings.show.min_seats,
    less_than_or_equal_to: Settings.show.max_seats
  }, unless: :no?
  validates :seats_used, absence: true, if: :no?
  validates :seats_used, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 0
  }, allow_blank: true, if: :yes?
  validates :show_id, inclusion: { in: ->(_) { Show.all.collect(&:id) } }
  validate :tickets_available?, unless: :no?, if: :requesting_more_seats?

  RSVP_NOTIFY_ATTRIBUTES = %w[first_name last_name seats_reserved response].freeze

  def update_confirmation_date
    return if !confirmed_changed? || !confirmed?

    self.confirmed_at = Time.zone.now
  end

  def clear_seats_if_no
    return if yes?

    self.seats_reserved = 0
    self.seats_used = nil
    self.confirmed = "unconfirmed"
  end

  def tickets_available?
    return true unless show&.confirmed? && show.sold_out?

    errors.add(:show, "is sold out")
    false
  end

  def requesting_more_seats?
    new_record? || seats_reserved > seats_reserved_was
  end

  def confirm!
    return unless yes?

    self.confirmed = "yes"
    save
  end

  def waitlist!
    return unless yes?

    self.confirmed = "waitlisted"
    save
  end

  def confirmed?
    confirmed == "yes"
  end

  def unconfirmed?
    confirmed.blank? || confirmed_unconfirmed?
  end

  def waitlisted?
    confirmed == "waitlisted"
  end

  def person_exists?
    Person.exists?(email: email)
  end

  def create_person
    return if person_exists?

    Person.create(first_name: first_name, last_name: last_name, email: email, phone_number: phone_number, postcode: postcode, notes: "RSVPd for show #{show.slug}")
  end

  def update_phone_number
    person = Person.find_by(email: email, phone_number: nil)
    person&.update(phone_number: phone_number)
  end

  def person
    Person.find_by(email: email)
  end

  def self.next_show
    RSVP.where(show: Show.next)
  end

  def can_confirm?
    !confirmed? && yes? && show&.can_confirm_rsvps?
  end

  def can_waitlist?
    !confirmed? && yes? && show&.can_waitlist_rsvps?
  end

  def self.next_show_attendees
    RSVP.where(show: Show.next, response: "yes", confirmed: "yes")
  end

  def self.unconfirmed_rsvps
    RSVP.where(show: Show.next, response: "yes", confirmed: %w[unconfirmed waitlisted])
  end

  def self.previous_show
    RSVP.where(show: Show.previous)
  end

  def self.previous_show_attendees
    RSVP.where(show: Show.previous, response: "yes", confirmed: "yes")
  end

  def sms_reminder
    "Reminder: You have #{seats_reserved.humanize} #{'seat'.pluralize(seats_reserved)} for the #{show.name} show on #{show.start_date} at #{show.start_time}."
  end

  def to_ld_json
    result = {
      "@context": "http://schema.org",
      "@type": "EventReservation",
      reservationNumber: uniqid,
      reservationStatus: "http://schema.org/Confirmed",
      underName: {
        "@type": "Person",
        name: full_name
      },
      reservationFor: {
        "@type": "MusicEvent",
        name: "#{show.name} House Concert",
        startDate: show.start.iso8601,
        endDate: show.end.iso8601,
        doorTime: show.door_time.iso8601,
        performer: {
          "@type": "Person",
          name: show.artists.collect(&:name).to_sentence,
          image: "#{Rails.application.routes.url_helpers.root_url}#{show.artists.first.photo}"
        },
        location: {
          "@type": "Place",
          name: Settings.site_name,
          address: {
            "@type": "PostalAddress",
            streetAddress: show.venue.address,
            addressLocality: show.venue.city,
            addressRegion: show.venue.province,
            postalCode: show.venue.postcode,
            addressCountry: show.venue.country
          }
        }
      },
      numSeats: seats_reserved,
      modifiedTime: updated_at.iso8601,
      modifyReservationUrl: Rails.application.routes.url_helpers.modify_rsvp_url(slug: show.slug, uniqid: uniqid)
    }

    result.to_json
  end
end

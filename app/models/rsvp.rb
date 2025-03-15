class RSVP < ApplicationRecord
  include NameRules
  include NameHelpers
  include NumberHelpers
  include IPAddress

  belongs_to :show

  before_save :downcase_email
  before_save :set_ip_address
  before_save :update_confirmation_date
  before_save :clear_seats_if_no
  after_save :update_phone_number
  after_save :notify_admin, unless: :confirmed?

  cattr_accessor :current_ip

  # From https://stackoverflow.com/a/1126031/135850
  default_value_for :uniqid do
    rand(2821109907456).to_s(36)
  end

  validates :first_name, presence: true, mixed_case: true, length: { minimum: 2 }, unless: :allowed_name_exception?
  validates :last_name, presence: true, mixed_case: true, length: { minimum: 2 }, unless: :allowed_name_exception?
  validates :email, email: true
  validates :phone_number, phone: { country: HC_CONFIG.default_country, set: true }, allow_blank: true
  validates :postcode, postal_code: { country: HC_CONFIG.default_country }, allow_blank: true
  validates :seats, numericality: {
    only_integer: true,
    greater_than_or_equal_to: HC_CONFIG.show.min_seats,
    less_than_or_equal_to: HC_CONFIG.show.max_seats
  }, unless: :no?
  validates :response, inclusion: { in: HC_CONFIG.rsvp.response }
  validates :show_id, inclusion: { in: ->(_) { Show.all.collect(&:id) } }

  def update_confirmation_date
    return if !confirmed_changed? || !confirmed?

    self.confirmed_at = Time.zone.now
  end

  def clear_seats_if_no
    return if yes?

    self.seats = 0
    self.confirmed = nil
  end

  # define .yes?, .no?
  HC_CONFIG.rsvp.response.each do |value|
    define_method(:"#{value}?") { response == value }

    # define .yes!, .no!
    # use update_attribute_s_ so the before_save actions fire
    define_method(:"#{value}!") { update(response: value) }
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
    confirmed == "no" || confirmed.empty?
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
    person = Person.where(email: email, phone_number: nil).first
    person&.update(phone_number: phone_number)
  end

  # notify_rsvp can be "yes", "all" (yes and no) or blank/false/empty string
  def notify_admin
    # don't notify of any RSVPs when notify is empty
    return if HC_CONFIG.notify_rsvp.empty?

    # don't notify of new "no" RSVPs when notify is "yes" only
    return if HC_CONFIG.notify_rsvp == "yes" and response != "yes" and previously_new_record?

    if saved_changes.include?("response") and saved_changes["response"][1] == "no"
      type = "cancel"
    elsif previously_new_record?
      type = "new"
    else
      type = "update"
    end

    old_seats = saved_changes.include?("seats") ? saved_changes["seats"][0] : nil

    # notify if there's a cancellation (no -> yes)
    # notify if there's a new yes
    # notify if there's a updated yes
    # notify if there's a new no (when notify is "all")
    RsvpsMailer.notify(self, type, old_seats).deliver_now
  end

  def sms_reminder
    "Reminder: You have #{seats.humanize} #{helper.pluralize(seats, 'seat')} for the #{show.name} show on #{show.start_date} at #{show.start_time}."
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
          name: HC_CONFIG.site_name,
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
      numSeats: seats,
      modifiedTime: updated_at.iso8601,
      modifyReservationUrl: Rails.application.routes.url_helpers.modify_rsvp_url(slug: show.slug, uniqid: uniqid)
    }

    result.to_json
  end
end

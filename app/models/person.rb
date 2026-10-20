class Person < ApplicationRecord
  include ContactDetails
  include NameHelpers
  include NumberHelpers
  include IPAddress

  has_many :person_venue_groups, dependent: :delete_all
  has_many :venue_groups, through: :person_venue_groups

  enum :status, { active: 0, bouncing: 1, moved: 2, removed: 3 }, default: :active

  # Active people in the default venue group who haven't RSVPd for the show.
  scope :invitable_for, lambda { |show|
    active.includes(:venue_groups)
          .where(venue_groups: { id: Settings.default_venue_group })
          .where("NOT EXISTS (SELECT 1 FROM rsvps WHERE rsvps.show_id = ? AND rsvps.email = people.email)", show.id)
  }

  before_validation :clean_variables
  before_save :set_ip_address
  before_save :update_removal_status
  before_save :ensure_venue_group

  attribute :uniqid, default: -> { SecureRandom.alphanumeric(Settings.uniqid_length) }

  def ensure_venue_group
    return unless venue_groups.empty?

    venue_groups << VenueGroup.find(Settings.default_venue_group)
  end

  def update_removal_status
    return if !status_changed? || !removed?

    self.removed_at = Time.zone.now
    self.removal_ip_address = Current.ip_address
  end

  def can_invite?
    active?
  end

  def can_rsvp_no?(next_show = nil)
    return false unless active?
    return Current.next_show_rsvpd_emails.exclude?(email) if Current.next_show_rsvpd_emails

    !RSVP.exists?(email: email, show: next_show || Show.next)
  end

  def attendance_history
    RSVP.attended(email).reorder("shows.start DESC").select(:start, :name, :seats_used, :seats_reserved)
  end

  def cancellation_history
    RSVP.joins(:show).where(email: email).where.not(cancelled_at: nil)
        .reorder("shows.start DESC").select(:start, :name, :cancelled_at)
  end

  # Shows attended and RSVPs cancelled, as [kind, rsvp] pairs (kind is
  # :attended or :cancelled), newest show first.
  def rsvp_history
    entries = attendance_history.map { |rsvp| [ :attended, rsvp ] } +
              cancellation_history.map { |rsvp| [ :cancelled, rsvp ] }
    entries.sort_by { |_, rsvp| rsvp.start }.reverse
  end
end

class Person < ApplicationRecord
  include NameRules
  include NameHelpers
  include NumberHelpers
  include IPAddress

  has_many :person_venue_groups, dependent: :destroy
  has_many :venue_groups, through: :person_venue_groups

  enum :status, { active: 0, bouncing: 1, moved: 2, removed: 3 }, default: :active

  before_validation :clean_variables
  before_save :downcase_email
  before_save :set_ip_address
  before_save :update_removal_status
  before_save :ensure_venue_group

  default_value_for :uniqid do
    SecureRandom.alphanumeric(8)
  end

  default_value_for :status, "active"

  validates :first_name, presence: true, mixed_case: true, length: { minimum: 2 }, unless: :allowed_name_exception?
  validates :last_name, presence: true, mixed_case: true, length: { minimum: 2 }, unless: :allowed_name_exception?
  validates :email, email: true
  validates :phone_number, phone: { country: Settings.default_country, set: true }, allow_blank: true
  validates :postcode, postal_code: { country: Settings.default_country }, allow_blank: true

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

  def attendance_history
    RSVP.joins(:show).merge(Show.occurred).where(email: email, response: "yes", confirmed: "yes", seats_reserved: 1..).reorder("shows.start DESC").select(:start, :name, :seats_used, :seats_reserved)
  end
end

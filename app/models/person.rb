class Person < ApplicationRecord
  include NameRules
  include NameHelpers
  include NumberHelpers
  include IPAddress

  has_and_belongs_to_many :venue_groups

  before_validation :clean_variables
  before_save :downcase_email
  before_save :set_ip_address
  before_save :update_removal_status
  before_save :ensure_venue_group

  cattr_accessor :current_ip

  # From https://stackoverflow.com/a/1126031/135850
  default_value_for :uniqid do
    rand(2821109907456).to_s(36)
  end

  default_value_for :status, 'active'

  validates :first_name, presence: true, mixed_case: true, length: { minimum: 2 }, unless: :allowed_name_exception?
  validates :last_name, presence: true, mixed_case: true, length: { minimum: 2 }, unless: :allowed_name_exception?
  validates :email, email: true
  validates :phone_number, phone: { country: HC_CONFIG.default_country, set: true }, allow_blank: true
  validates :postcode, postal_code: { country: HC_CONFIG.default_country }, allow_blank: true
  validates :status, inclusion: { in: HC_CONFIG.person.status }

  # define .active?, .bouncing?, .moved?, .removed?, .deleted?, .vacation? methods
  HC_CONFIG.person.status.each do |value|
    define_method("#{value.tr(' ', '_')}?") { status == value }

    # use update_attribute_s_ so the before_save actions fire
    define_method("#{value.tr(' ', '_')}!") { update_attributes(status: value) }
  end

  def ensure_venue_group
    return unless venue_groups.empty?

    venue_groups << VenueGroup.find(HC_CONFIG.default_venue_group)
  end

  def update_removal_status
    return if !status_changed? || !removed?

    self.removed_at = Time.now
    self.removal_ip_address = current_ip
  end
end

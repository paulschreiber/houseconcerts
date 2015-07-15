class Person < ActiveRecord::Base
  has_and_belongs_to_many :venue_groups

  before_validation :clean_variables
  before_save :downcase_email
  before_save :set_ip_address
  before_save :update_removal_status
  before_save :ensure_venue_group

  # From https://stackoverflow.com/a/1126031/135850
  default_value_for :uniqid do
    rand(2821109907456).to_s(36)
  end

  cattr_accessor :current_ip

  default_value_for :status, "active"

  validates :first_name, presence: true, mixed_case: true
  validates :last_name, presence: true, mixed_case: true
  validates :email, email: true
  validates :postcode, postal_code: { country: HC_CONFIG.default_country }, allow_blank: true
  validates :status, inclusion: { in: HC_CONFIG.person.status }

  def ensure_venue_group
    if venue_groups.empty?
      self.venue_groups << VenueGroup.find(HC_CONFIG.default_venue_group)
    end
  end

  def update_removal_status
    if self.status_changed? and self.status == "removed"
      self.removed_at = DateTime.now
      self.removal_ip_address = current_ip
    end
  end

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def set_ip_address
    self.ip_address = current_ip if ip_address.nil?
  end

  def email_address_with_name
    return unless email.present?
    if full_name.present?
      "\"#{full_name}\" <#{email}>"
    else
      email
    end
  end

end

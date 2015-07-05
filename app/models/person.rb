class Person < ActiveRecord::Base
  has_and_belongs_to_many :venue_groups

  before_validation :clean_variables
  before_save :downcase_email
  before_save :set_ip_address
  before_save :update_removal_status

  # From https://stackoverflow.com/a/1126031/135850
  default_value_for :uniqid do
    rand(2821109907456).to_s(36)
  end

  default_value_for :status, HC_CONFIG.person.status[:active]

  validates :first_name, presence: true, mixed_case: true
  validates :last_name, presence: true, mixed_case: true
  validates :email, presence: true, email: true
  validates :postcode, postal_code: { country: HC_CONFIG.default_country }
  validates :status, inclusion: { in: HC_CONFIG.person.status.values }

end

class Person < ActiveRecord::Base
  has_and_belongs_to_many :venue_groups

  before_validation :clean_variables
  before_save :downcase_email
  before_save :set_ip_address
  before_save :update_removal_status
end

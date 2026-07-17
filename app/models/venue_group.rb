class VenueGroup < ApplicationRecord
  has_many :venue_group_venues, dependent: :destroy
  has_many :venues, through: :venue_group_venues

  has_many :person_venue_groups, dependent: :destroy
  has_many :people, through: :person_venue_groups

  validates :name, presence: true
end

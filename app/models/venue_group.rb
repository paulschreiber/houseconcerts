class VenueGroup < ApplicationRecord
  has_many :venue_group_venues, dependent: :delete_all
  has_many :venues, through: :venue_group_venues

  has_many :person_venue_groups, dependent: :delete_all
  has_many :people, through: :person_venue_groups

  validates :name, presence: true
end

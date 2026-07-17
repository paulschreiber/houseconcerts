class VenueGroup < ApplicationRecord
  has_and_belongs_to_many :venues

  has_many :person_venue_groups, dependent: :destroy
  has_many :people, through: :person_venue_groups

  validates :name, presence: true
end

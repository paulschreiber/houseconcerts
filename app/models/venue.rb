class Venue < ActiveRecord::Base
  has_and_belongs_to_many :venue_groups
  has_many :shows
end

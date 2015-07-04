class Show < ActiveRecord::Base
  has_and_belongs_to_many :artists
  has_many :rsvps
  belongs_to :venue
end

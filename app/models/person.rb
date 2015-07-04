class Person < ActiveRecord::Base
  has_and_belongs_to_many :venue_groups
end

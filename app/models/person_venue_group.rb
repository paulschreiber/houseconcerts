class PersonVenueGroup < ApplicationRecord
  self.table_name = "people_venue_groups"

  belongs_to :person
  belongs_to :venue_group
end

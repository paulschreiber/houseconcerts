class PersonVenueGroup < ApplicationRecord
  self.table_name = "people_venue_groups"

  include JoinRecord

  join_belongs_to :person, :venue_group
end

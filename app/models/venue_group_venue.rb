class VenueGroupVenue < ApplicationRecord
  self.table_name = "venue_groups_venues"

  include JoinRecord

  join_belongs_to :venue_group, :venue
end

class VenueGroupVenue < ApplicationRecord
  self.table_name = "venue_groups_venues"

  belongs_to :venue_group
  belongs_to :venue

  validates :venue_group_id, uniqueness: { scope: :venue_id }
end

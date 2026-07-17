class ArtistShow < ApplicationRecord
  self.table_name = "artists_shows"

  belongs_to :artist
  belongs_to :show
end

class ArtistShow < ApplicationRecord
  self.table_name = "artists_shows"

  belongs_to :artist
  belongs_to :show

  validates :artist_id, uniqueness: { scope: :show_id }
end

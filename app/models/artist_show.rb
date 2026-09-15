class ArtistShow < ApplicationRecord
  self.table_name = "artists_shows"

  include JoinRecord

  join_belongs_to :artist, :show
end

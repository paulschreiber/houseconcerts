class CreateJoinTableArtistsShows < ActiveRecord::Migration[4.2]
  def change
    create_join_table :artists, :shows do |t|
      t.index [:artist_id, :show_id]
      t.index [:show_id, :artist_id]
    end
  end
end

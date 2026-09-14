class AddIntegrityConstraintsToJoinTables < ActiveRecord::Migration[8.1]
  def up
    # These join tables were never constrained by a foreign key, so rows
    # pointing at a since-deleted artist/show/person/venue/venue_group have
    # accumulated over time (e.g. from a deletion path that bypassed the
    # owning model's destroy callback). They have to go before a foreign key
    # can be added.
    execute <<~SQL.squish
      DELETE artists_shows FROM artists_shows
      LEFT JOIN artists ON artists.id = artists_shows.artist_id
      LEFT JOIN shows ON shows.id = artists_shows.show_id
      WHERE artists.id IS NULL OR shows.id IS NULL
    SQL

    execute <<~SQL.squish
      DELETE people_venue_groups FROM people_venue_groups
      LEFT JOIN people ON people.id = people_venue_groups.person_id
      LEFT JOIN venue_groups ON venue_groups.id = people_venue_groups.venue_group_id
      WHERE people.id IS NULL OR venue_groups.id IS NULL
    SQL

    execute <<~SQL.squish
      DELETE venue_groups_venues FROM venue_groups_venues
      LEFT JOIN venue_groups ON venue_groups.id = venue_groups_venues.venue_group_id
      LEFT JOIN venues ON venues.id = venue_groups_venues.venue_id
      WHERE venue_groups.id IS NULL OR venues.id IS NULL
    SQL

    change_table :artists_shows, bulk: true do |t|
      t.remove_index column: %i[artist_id show_id], name: "index_artists_shows_on_artist_id_and_show_id"
      t.index %i[artist_id show_id], unique: true, name: "index_artists_shows_on_artist_id_and_show_id"
      t.foreign_key :artists unless t.foreign_key_exists?(:artists)
      t.foreign_key :shows unless t.foreign_key_exists?(:shows)
    end

    change_table :people_venue_groups, bulk: true do |t|
      t.remove_index column: %i[person_id venue_group_id], name: "index_people_venue_groups_on_person_id_and_venue_group_id"
      t.index %i[person_id venue_group_id], unique: true, name: "index_people_venue_groups_on_person_id_and_venue_group_id"
      t.foreign_key :people unless t.foreign_key_exists?(:people)
      t.foreign_key :venue_groups unless t.foreign_key_exists?(:venue_groups)
    end

    change_table :venue_groups_venues, bulk: true do |t|
      t.remove_index column: %i[venue_group_id venue_id], name: "index_venue_groups_venues_on_venue_group_id_and_venue_id"
      t.index %i[venue_group_id venue_id], unique: true, name: "index_venue_groups_venues_on_venue_group_id_and_venue_id"
      t.foreign_key :venue_groups unless t.foreign_key_exists?(:venue_groups)
      t.foreign_key :venues unless t.foreign_key_exists?(:venues)
    end
  end

  def down
    change_table :artists_shows, bulk: true do |t|
      t.remove_foreign_key :artists if t.foreign_key_exists?(:artists)
      t.remove_foreign_key :shows if t.foreign_key_exists?(:shows)
      t.remove_index column: %i[artist_id show_id], name: "index_artists_shows_on_artist_id_and_show_id"
      t.index %i[artist_id show_id], name: "index_artists_shows_on_artist_id_and_show_id"
    end

    change_table :people_venue_groups, bulk: true do |t|
      t.remove_foreign_key :people if t.foreign_key_exists?(:people)
      t.remove_foreign_key :venue_groups if t.foreign_key_exists?(:venue_groups)
      t.remove_index column: %i[person_id venue_group_id], name: "index_people_venue_groups_on_person_id_and_venue_group_id"
      t.index %i[person_id venue_group_id], name: "index_people_venue_groups_on_person_id_and_venue_group_id"
    end

    change_table :venue_groups_venues, bulk: true do |t|
      t.remove_foreign_key :venue_groups if t.foreign_key_exists?(:venue_groups)
      t.remove_foreign_key :venues if t.foreign_key_exists?(:venues)
      t.remove_index column: %i[venue_group_id venue_id], name: "index_venue_groups_venues_on_venue_group_id_and_venue_id"
      t.index %i[venue_group_id venue_id], name: "index_venue_groups_venues_on_venue_group_id_and_venue_id"
    end
  end
end

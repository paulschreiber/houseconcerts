class ChangePrimaryKeyToBigint < ActiveRecord::Migration[6.1]
  def change

    remove_foreign_key "shows", "venues"

    remove_index :artists_shows, column: ["artist_id", "show_id"], name: "index_artists_shows_on_artist_id_and_show_id"
    remove_index :artists_shows, column: ["show_id", "artist_id"], name: "index_artists_shows_on_show_id_and_artist_id"
    remove_index :friendly_id_slugs, column: ["sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_id"
    remove_index :people_venue_groups, column: ["person_id", "venue_group_id"], name: "index_people_venue_groups_on_person_id_and_venue_group_id"
    remove_index :people_venue_groups, column: ["venue_group_id", "person_id"], name: "index_people_venue_groups_on_venue_group_id_and_person_id"
    remove_index :rsvps, column: ["show_id", "email"], name: "index_rsvps_on_show_id_and_email"
    remove_index :rsvps, column: ["show_id"], name: "index_rsvps_on_show_id"
    remove_index :shows, column: ["venue_id"], name: "index_shows_on_venue_id"
    remove_index :venue_groups_venues, column: ["venue_group_id", "venue_id"], name: "index_venue_groups_venues_on_venue_group_id_and_venue_id"
    remove_index :venue_groups_venues, column: ["venue_id", "venue_group_id"], name: "index_venue_groups_venues_on_venue_id_and_venue_group_id"

    change_column :admins, :id, :bigint
    change_column :artists, :id, :bigint
    change_column :opens, :id, :bigint
    change_column :people, :id, :bigint
    change_column :rsvps, :id, :bigint
    change_column :rsvps, :show_id, :bigint

    change_column :shows, :id, :bigint
    change_column :shows, :venue_id, :bigint

    change_column :venues, :id, :bigint

    change_column :artists_shows, :artist_id, :bigint
    change_column :artists_shows, :show_id, :bigint

    change_column :people_venue_groups, :person_id, :bigint
    change_column :people_venue_groups, :venue_group_id, :bigint

    change_column :venue_groups, :id, :bigint
    change_column :venue_groups_venues, :venue_id, :bigint
    change_column :venue_groups_venues, :venue_group_id, :bigint

    change_column :friendly_id_slugs, :id, :bigint
    change_column :friendly_id_slugs, :sluggable_id, :bigint

    add_foreign_key "shows", "venues"

    add_index :artists_shows, ["artist_id", "show_id"], name: "index_artists_shows_on_artist_id_and_show_id"
    add_index :artists_shows, ["show_id", "artist_id"], name: "index_artists_shows_on_show_id_and_artist_id"
    add_index :friendly_id_slugs, ["sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_id"
    add_index :people_venue_groups, ["person_id", "venue_group_id"], name: "index_people_venue_groups_on_person_id_and_venue_group_id"
    add_index :people_venue_groups, ["venue_group_id", "person_id"], name: "index_people_venue_groups_on_venue_group_id_and_person_id"
    add_index :rsvps, ["show_id", "email"], name: "index_rsvps_on_show_id_and_email"
    add_index :rsvps, ["show_id"], name: "index_rsvps_on_show_id"
    add_index :shows, ["venue_id"], name: "index_shows_on_venue_id"
    add_index :venue_groups_venues, ["venue_group_id", "venue_id"], name: "index_venue_groups_venues_on_venue_group_id_and_venue_id"
    add_index :venue_groups_venues, ["venue_id", "venue_group_id"], name: "index_venue_groups_venues_on_venue_id_and_venue_group_id"
  end
end

class StandardizeCharsetToUtf8mb4 < ActiveRecord::Migration[8.1]
  TABLES = %w[
    admins
    artists
    artists_shows
    friendly_id_slugs
    opens
    people
    people_venue_groups
    rsvps
    schema_migrations
    shows
    venue_groups
    venue_groups_venues
    venues
  ].freeze

  def up
    execute "ALTER DATABASE `#{connection.current_database}` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci"

    TABLES.each do |table|
      execute "ALTER TABLE #{table} CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci"
    end
  end

  def down
    execute "ALTER DATABASE `#{connection.current_database}` DEFAULT CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci"

    TABLES.each do |table|
      execute "ALTER TABLE #{table} CONVERT TO CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci"
    end
  end
end

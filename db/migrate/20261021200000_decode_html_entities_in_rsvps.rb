class DecodeHtmlEntitiesInRsvps < ActiveRecord::Migration[8.1]
  # ModelCleaners stored text as HTML, so & was saved as &amp; (and <, > and
  # non-breaking spaces as &lt;, &gt; and &nbsp;), and pages showed it
  # literally. In the data, that's RSVP last names (couples, like
  # "Smith &amp; Li") and referrer URLs. &amp; goes last, so each entity is
  # decoded once ("&amp;lt;" becomes "&lt;", not "<").
  #
  # A direct UPDATE, so no callbacks run (saving an RSVP emails the admin)
  # and updated_at is unchanged.
  COLUMNS = %w[last_name referrer].freeze
  ENTITIES = { "&lt;" => "<", "&gt;" => ">", "&nbsp;" => "\u00a0", "&amp;" => "&" }.freeze

  def up
    assignments = COLUMNS.map { |column| "#{column} = #{decode(column)}" }.join(", ")
    matches = COLUMNS.map { |column| "#{column} LIKE '%&%'" }.join(" OR ")

    updated = exec_update("UPDATE rsvps SET #{assignments} WHERE #{matches}")
    say "Decoded #{updated} RSVPs"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

    def decode(column)
      ENTITIES.reduce(column) { |sql, (entity, text)| "REPLACE(#{sql}, #{connection.quote(entity)}, #{connection.quote(text)})" }
    end
end

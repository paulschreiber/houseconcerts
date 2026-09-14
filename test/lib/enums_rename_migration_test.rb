require "test_helper"
require Rails.root.join("db/migrate/20250509150950_enums_rename")

class EnumsRenameMigrationTest < ActiveSupport::TestCase
  # This migration used to crash mid-run (a NOT NULL violation during the
  # RSVP backfill, fixed separately in PR #413) after already renaming every
  # table's string column and adding its integer replacement - DDL isn't
  # transactional in MySQL, so that partial state survives the crash.
  # Re-running the unguarded migration against it would immediately fail
  # again trying to rename columns that no longer exist under their old
  # names. This reproduces that exact leftover state - on all three tables,
  # since the real crash happens only after all three renames have already
  # run - and confirms #up now resumes and finishes cleanly instead.
  #
  # old_* is backfilled here so each row round-trips to its own current
  # value, since DDL implicitly commits MySQL's transaction and this test
  # can't rely on the usual per-test rollback to undo a botched backfill.
  test "up finishes cleanly when re-run against a state left by a previous crash" do
    connection = ActiveRecord::Base.connection

    connection.add_column :rsvps, :old_response, :string
    connection.add_column :rsvps, :old_confirmed, :string
    connection.add_column :shows, :old_status, :string
    connection.add_column :people, :old_status, :string
    RSVP.reset_column_information
    Show.reset_column_information
    Person.reset_column_information

    old_confirmed_for = { "unconfirmed" => nil, "waitlisted" => "waitlisted", "confirmed" => "yes" }
    RSVP.find_each do |rsvp|
      rsvp.update_columns(old_response: rsvp.response, old_confirmed: old_confirmed_for.fetch(rsvp.confirmed)) # rubocop:disable Rails/SkipsModelValidations
    end

    Show.find_each do |show|
      old_status = case show.availability
      when "waitlisted" then "waitlisted"
      when "sold_out" then "sold out"
      else show.status
      end
      show.update_columns(old_status: old_status) # rubocop:disable Rails/SkipsModelValidations
    end

    Person.find_each { |person| person.update_columns(old_status: person.status) } # rubocop:disable Rails/SkipsModelValidations

    rsvps_before = RSVP.order(:id).map { |r| [ r.id, r.response, r.confirmed ] }
    shows_before = Show.order(:id).map { |s| [ s.id, s.status, s.availability ] }
    people_before = Person.order(:id).map { |p| [ p.id, p.status ] }

    EnumsRename.new.up

    RSVP.reset_column_information
    Show.reset_column_information
    Person.reset_column_information

    assert_not_includes RSVP.column_names, "old_response"
    assert_not_includes RSVP.column_names, "old_confirmed"
    assert_not_includes Show.column_names, "old_status"
    assert_not_includes Person.column_names, "old_status"

    assert_equal(rsvps_before, RSVP.order(:id).map { |r| [ r.id, r.response, r.confirmed ] })
    assert_equal(shows_before, Show.order(:id).map { |s| [ s.id, s.status, s.availability ] })
    assert_equal(people_before, Person.order(:id).map { |p| [ p.id, p.status ] })
  ensure
    RSVP.reset_column_information
    Show.reset_column_information
    Person.reset_column_information
    connection.remove_column(:rsvps, :old_response) if connection.column_exists?(:rsvps, :old_response)
    connection.remove_column(:rsvps, :old_confirmed) if connection.column_exists?(:rsvps, :old_confirmed)
    connection.remove_column(:shows, :old_status) if connection.column_exists?(:shows, :old_status)
    connection.remove_column(:people, :old_status) if connection.column_exists?(:people, :old_status)
  end
end

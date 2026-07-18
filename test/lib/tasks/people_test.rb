require "test_helper"

class PeopleRakeTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    load_rake_tasks
    %w[list_nonsubscribers add_phone_numbers add_nonsubscribers list_unsubscribers import_subscribers].each do |task|
      Rake::Task["people:#{task}"].reenable
    end
  end

  test "list_nonsubscribers lists rsvps for the most recent show that aren't subscribed" do
    rsvp = RSVP.create!(show: shows(:past), email: "nonsub@example.com", first_name: "Non", last_name: "Sub", response: "yes", seats_reserved: 1)

    out, = capture_io { Rake::Task["people:list_nonsubscribers"].invoke }

    assert_includes out, "Found 1 who RSVPd for #{shows(:past).name} and are not subscribed"
    assert_includes out, rsvp.email_address_with_name
  end

  test "add_phone_numbers backfills a person's phone number from a matching rsvp" do
    rsvp = RSVP.create!(show: shows(:upcoming), email: "backfill@example.com", first_name: "Back", last_name: "Fill", response: "yes", seats_reserved: 1, phone_number: "2125551234")
    person = Person.create!(first_name: "Back", last_name: "Fill", email: rsvp.email, status: "active")
    assert_nil person.phone_number

    capture_io { Rake::Task["people:add_phone_numbers"].invoke }

    assert_equal rsvp.reload.phone_number, person.reload.phone_number
  end

  test "add_nonsubscribers creates people for rsvps that aren't already subscribed" do
    rsvp = RSVP.create!(show: shows(:past), email: "newsub@example.com", first_name: "New", last_name: "Sub", response: "yes", seats_reserved: 1)

    assert_difference("Person.count", 1) do
      capture_io { Rake::Task["people:add_nonsubscribers"].invoke }
    end
    assert Person.exists?(email: rsvp.email)
  end

  test "list_unsubscribers lists removed people" do
    person = people(:one)
    person.update!(status: "removed")

    out, = capture_io { Rake::Task["people:list_unsubscribers"].invoke }

    assert_includes out, person.email_address_with_name
  end

  test "import_subscribers exits when no filename is given" do
    assert_raises(SystemExit) do
      capture_io { Rake::Task["people:import_subscribers"].invoke }
    end
  end

  test "import_subscribers exits when the file doesn't exist" do
    assert_raises(SystemExit) do
      capture_io { Rake::Task["people:import_subscribers"].invoke("/nonexistent/file.txt") }
    end
  end

  test "import_subscribers exits when the file is blank" do
    file = Tempfile.new
    begin
      assert_raises(SystemExit) do
        capture_io { Rake::Task["people:import_subscribers"].invoke(file.path) }
      end
    ensure
      file.close!
    end
  end

  test "import_subscribers creates people from well-formed lines and skips malformed ones" do
    file = Tempfile.new
    begin
      file.write("Jane Doe <jane-import@example.com>\nBad Line\nJohn Smith <john-import@example.com>")
      file.close

      out, = capture_io { Rake::Task["people:import_subscribers"].invoke(file.path) }

      assert Person.exists?(email: "jane-import@example.com")
      assert Person.exists?(email: "john-import@example.com")
      assert_includes out, "Skipping: [Bad Line]"
      assert_includes out, "jane-import@example.com"
      assert_includes out, "john-import@example.com"
    ensure
      file.close!
    end
  end

  test "import_subscribers reports duplicates instead of raising" do
    Person.create!(first_name: "Existing", last_name: "Person", email: "duplicate-import@example.com", status: "active")

    file = Tempfile.new
    begin
      file.write("Existing Person <duplicate-import@example.com>")
      file.close

      out, = capture_io { Rake::Task["people:import_subscribers"].invoke(file.path) }

      assert_includes out, "Duplicate: [Existing Person <duplicate-import@example.com>]"
    ensure
      file.close!
    end
  end
end

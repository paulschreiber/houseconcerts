require "test_helper"

module Madmin
  class PeopleControllerTest < ActionDispatch::IntegrationTest
    include ActionMailer::TestHelper

    setup do
      sign_in admins(:one)
      @person = people(:one)
    end

    test "edit renders successfully" do
      get edit_madmin_person_path(@person)

      assert_response :success
    end

    test "new renders successfully" do
      get new_madmin_person_path

      assert_response :success
    end

    test "show renders successfully" do
      get madmin_person_path(@person)

      assert_response :success
    end

    test "create creates a person and redirects to their show page" do
      assert_difference "Person.count", 1 do
        post madmin_people_path, params: { person: { first_name: "New", last_name: "Person", email: "new.person@example.com" } }
      end

      assert_redirected_to madmin_person_path(Person.last)
    end

    test "create with invalid attributes renders new" do
      assert_no_difference "Person.count" do
        post madmin_people_path, params: { person: { first_name: "" } }
      end

      assert_response :unprocessable_content
    end

    test "update updates the person and redirects to their show page" do
      patch madmin_person_path(@person), params: { person: { first_name: "Updated" } }

      assert_equal "Updated", @person.reload.first_name
      assert_redirected_to madmin_person_path(@person)
    end

    test "update with invalid attributes renders edit" do
      patch madmin_person_path(@person), params: { person: { first_name: "" } }

      assert_response :unprocessable_content
      assert_equal "Test", @person.reload.first_name
    end

    test "destroy destroys the person and redirects to the index page" do
      person = people(:subscribed)

      assert_difference "Person.count", -1 do
        delete madmin_person_path(person)
      end

      assert_redirected_to madmin_people_path
    end

    test "invite emails the person and redirects with a notice" do
      assert_emails 1 do
        patch invite_madmin_person_path(@person)
      end

      assert_redirected_to madmin_people_path
      assert_match(/Invited #{Regexp.escape(@person.full_name)}/, flash[:notice])
    end

    test "invite does not email an inactive person" do
      @person.update!(status: "removed")

      assert_no_emails do
        patch invite_madmin_person_path(@person)
      end

      assert_redirected_to madmin_people_path
      assert_match(/can’t be invited/, flash[:alert])
    end

    test "invite does not email when there is no upcoming show" do
      Show.upcoming.update_all(status: "cancelled") # rubocop:disable Rails/SkipsModelValidations

      assert_no_emails do
        patch invite_madmin_person_path(@person)
      end

      assert_redirected_to madmin_people_path
      assert_match(/can’t be invited/, flash[:alert])
    end

    test "invite shows an alert instead of a false success notice when InvitePerson fails" do
      original_invite = InvitesMailer.method(:invite)
      InvitesMailer.define_singleton_method(:invite) { |*_args| raise "simulated enqueue failure" }

      begin
        assert_no_emails do
          patch invite_madmin_person_path(@person)
        end
      ensure
        InvitesMailer.define_singleton_method(:invite, original_invite)
      end

      assert_redirected_to madmin_people_path
      assert_match(/can’t be invited/, flash[:alert])
    end

    test "index shows an Invite button for an active person" do
      get madmin_people_path

      assert_response :success
      assert_match(/>Invite</, response.body)
    end

    test "index has an RSVP button linking to the person's RSVP page for the next show" do
      get madmin_people_path

      assert_select "a[href=?][target=_blank][rel='noopener noreferrer']", modify_rsvp_path(slug: Show.next.slug, uniqid: @person.uniqid),
                    text: "RSVP"
    end

    test "show has the RSVP button too, until the person has RSVPd for the next show" do
      get madmin_person_path(@person)
      assert_select "a[href=?]", modify_rsvp_path(slug: Show.next.slug, uniqid: @person.uniqid), text: "RSVP"

      RSVP.create!(show: Show.next, first_name: @person.first_name, last_name: @person.last_name, email: @person.email,
                   response: "yes", seats_reserved: 1)
      get madmin_person_path(@person)
      assert_select "a[href=?]", modify_rsvp_path(slug: Show.next.slug, uniqid: @person.uniqid), count: 0
    end

    test "index hides the RSVP button once the person has RSVPd for the next show" do
      RSVP.create!(show: Show.next, first_name: @person.first_name, last_name: @person.last_name, email: @person.email,
                   response: "yes", seats_reserved: 1)

      get madmin_people_path

      assert_select "a[href=?]", modify_rsvp_path(slug: Show.next.slug, uniqid: @person.uniqid), count: 0
    end

    test "index hides the RSVP button once a person is removed, or when there's no upcoming show" do
      @person.removed!
      get madmin_people_path
      assert_select "a[href=?]", modify_rsvp_path(slug: Show.next.slug, uniqid: @person.uniqid), count: 0

      @person.active!
      Show.update_all(start: 1.year.ago, end: 1.year.ago + 2.hours) # rubocop:disable Rails/SkipsModelValidations
      get madmin_people_path
      assert_select "a", text: "RSVP", count: 0
    end

    test "index hides the Invite button once a person is removed" do
      Person.update_all(status: "removed") # rubocop:disable Rails/SkipsModelValidations

      get madmin_people_path

      assert_response :success
      assert_no_match(/>Invite</, response.body)
    end

    test "index hides the Invite button when the upcoming show is cancelled" do
      Show.upcoming.update_all(status: "cancelled") # rubocop:disable Rails/SkipsModelValidations

      get madmin_people_path

      assert_response :success
      assert_no_match(/>Invite</, response.body)
    end

    test "index hides the Invite button when there are no upcoming shows at all" do
      Show.upcoming.destroy_all

      get madmin_people_path

      assert_response :success
      assert_no_match(/>Invite</, response.body)
    end

    test "rsvp_no records a no RSVP and redirects with a notice" do
      assert_difference "RSVP.count", 1 do
        patch rsvp_no_madmin_person_path(@person)
      end

      assert RSVP.find_by(email: @person.email, show: Show.next).no?
      assert_redirected_to madmin_people_path
      assert_match(/Recorded a “no” RSVP for #{Regexp.escape(@person.full_name)}/, flash[:notice])
    end

    test "rsvp_no looks up the next show only once, not once per can_rsvp_no?/RSVPNo call" do
      next_show_queries = 0
      callback = ->(*, payload) { next_show_queries += 1 if payload[:sql]&.include?("ORDER BY `shows`.`start` ASC LIMIT 1") }

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        patch rsvp_no_madmin_person_path(@person)
      end

      assert_redirected_to madmin_people_path
      assert_equal 1, next_show_queries
    end

    test "rsvp_no does not record a no RSVP for a removed person" do
      @person.update!(status: "removed")

      assert_no_difference "RSVP.count" do
        patch rsvp_no_madmin_person_path(@person)
      end

      assert_redirected_to madmin_people_path
      assert_match(/Can’t record a “no” RSVP/, flash[:alert])
    end

    test "rsvp_no does not record a no RSVP when there is no upcoming show" do
      Show.upcoming.update_all(status: "cancelled") # rubocop:disable Rails/SkipsModelValidations

      assert_no_difference "RSVP.count" do
        patch rsvp_no_madmin_person_path(@person)
      end

      assert_redirected_to madmin_people_path
      assert_match(/Can’t record a “no” RSVP/, flash[:alert])
    end

    test "rsvp_no shows an alert instead of a false success notice when the save fails" do
      @person.update_column(:first_name, "") # rubocop:disable Rails/SkipsModelValidations

      assert_no_difference "RSVP.count" do
        patch rsvp_no_madmin_person_path(@person)
      end

      assert_redirected_to madmin_people_path
      assert_match(/Can’t record a “no” RSVP/, flash[:alert])
    end

    test "index shows an RSVP No button for an active person" do
      get madmin_people_path

      assert_response :success
      assert_match(/>RSVP No</, response.body)
    end

    test "index hides the RSVP No button once a person is removed" do
      Person.update_all(status: "removed") # rubocop:disable Rails/SkipsModelValidations

      get madmin_people_path

      assert_response :success
      assert_no_match(/>RSVP No</, response.body)
    end

    test "index hides the RSVP No button when there are no upcoming shows at all" do
      Show.upcoming.destroy_all

      get madmin_people_path

      assert_response :success
      assert_no_match(/>RSVP No</, response.body)
    end

    test "index hides the RSVP No button once the person has RSVPd for the next show" do
      RSVP.create!(first_name: @person.first_name, last_name: @person.last_name, email: @person.email,
                   show: Show.next, response: "yes", seats_reserved: 2)

      get madmin_people_path

      assert_response :success
      assert_no_match(%r{action="/backstage/people/#{@person.id}/rsvp_no"}, response.body)
    end

    test "index computes RSVP No eligibility for the whole page in one query, not once per row" do
      other = Person.create!(first_name: "Other", last_name: "Person", email: "other-person@example.com", status: "active")
      RSVP.create!(first_name: @person.first_name, last_name: @person.last_name, email: @person.email,
                   show: Show.next, response: "yes", seats_reserved: 2)

      rsvp_exists_queries = 0
      callback = ->(*, payload) { rsvp_exists_queries += 1 if payload[:sql]&.include?("SELECT 1 AS one FROM `rsvps`") }

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        get madmin_people_path
      end

      assert_response :success
      assert_equal 0, rsvp_exists_queries
      assert_no_match(%r{action="/backstage/people/#{@person.id}/rsvp_no"}, response.body)
      assert_match(%r{action="/backstage/people/#{other.id}/rsvp_no"}, response.body)
    end

    test "rsvp_no does not record a second no RSVP once the person has already RSVPd" do
      RSVP.create!(first_name: @person.first_name, last_name: @person.last_name, email: @person.email,
                   show: Show.next, response: "yes", seats_reserved: 2)

      assert_no_difference "RSVP.count" do
        patch rsvp_no_madmin_person_path(@person)
      end

      assert_redirected_to madmin_people_path
      assert_match(/Can’t record a “no” RSVP/, flash[:alert])
    end

    test "sorting by Name orders people by last name, then first name" do
      Person.delete_all
      [ %w[Zed Adams], %w[Amy Baker], %w[Bob Adams] ].each do |first_name, last_name|
        Person.create!(first_name:, last_name:, email: "#{first_name}.#{last_name}@example.com".downcase)
      end

      { "asc" => [ "Bob Adams", "Zed Adams", "Amy Baker" ], "desc" => [ "Amy Baker", "Zed Adams", "Bob Adams" ] }.each do |direction, expected|
        get madmin_people_path(sort: "full_name", direction:)

        names = response.parsed_body.css("tbody tr").map { |row| row.text[/(Bob Adams|Zed Adams|Amy Baker)/] }
        assert_equal expected, names, direction
      end
    end

    test "the removed scope lists the most recently removed first, with the sort arrow on Removed At" do
      older = Person.create!(first_name: "Amy", last_name: "Adams", email: "amy@example.com")
      newer = Person.create!(first_name: "Zed", last_name: "Zane", email: "zed@example.com")
      # Removing someone sets removed_at to now, so backdate them afterwards.
      [ older, newer ].each(&:removed!)
      older.update_column(:removed_at, 2.days.ago) # rubocop:disable Rails/SkipsModelValidations
      newer.update_column(:removed_at, 1.day.ago) # rubocop:disable Rails/SkipsModelValidations

      get madmin_people_path(scope: "removed")

      assert_operator response.body.index("Zed Zane"), :<, response.body.index("Amy Adams")
      assert_select "thead th a[href*='sort=removed_at'] svg"
      assert_select "thead th a[href*='sort=full_name'][href*='direction=asc']"
    end

    test "index links to the import page" do
      get madmin_people_path

      assert_select "a[href=?]", import_madmin_people_path, text: "Import"
    end

    test "import shows the form" do
      get import_madmin_people_path

      assert_response :success
      assert_select "form[action=?][enctype='multipart/form-data'] textarea[name=text]", import_madmin_people_path
      assert_select ".drop-zone[data-controller=drop-zone] input[type=file][name=file][accept='.csv,.tsv,.txt']"
    end

    test "run_import imports pasted text and lists what happened" do
      Person.create!(first_name: "John", last_name: "Doe", email: "john.doe@example.com")

      post import_madmin_people_path, params: { text: "Jane Smith <jane.smith@example.com>\nJohn,Doe,john.doe@example.com\nnonsense" }

      assert_response :success
      assert Person.exists?(email: "jane.smith@example.com")
      assert_includes response.body, "Added 1 person: Jane Smith."
      assert_select "h2", text: "Skipped (1)"
      assert_select "h2", text: "Couldn’t import (1)"
      assert_select "textarea[name=text]", text: ""
    end

    test "run_import imports an uploaded file" do
      file = Tempfile.new([ "people", ".csv" ])
      file.write("Jane,Smith,jane.smith@example.com\n")
      file.close

      post import_madmin_people_path, params: { file: Rack::Test::UploadedFile.new(file.path, "text/csv") }

      assert_response :success
      assert Person.exists?(email: "jane.smith@example.com")
    ensure
      file&.unlink
    end

    test "run_import rejects a file with the wrong extension, one that isn't text, or nothing at all" do
      file = Tempfile.new([ "people", ".png" ])
      file.binmode
      file.write("\x89PNG\r\n\x1A\n\x00\x00".b)
      file.close

      post import_madmin_people_path, params: { file: Rack::Test::UploadedFile.new(file.path, "image/png") }
      assert_response :unprocessable_content
      assert_select ".alert-danger", text: /isn’t a \.csv, \.tsv or \.txt file/

      renamed = "#{file.path}.txt"
      File.rename(file.path, renamed)
      post import_madmin_people_path, params: { file: Rack::Test::UploadedFile.new(renamed, "text/plain") }
      assert_response :unprocessable_content
      assert_select ".alert-danger", text: /isn’t a text file/

      post import_madmin_people_path, params: { text: "  " }
      assert_response :unprocessable_content
      assert_select ".alert-danger", text: /Paste some names/
    ensure
      file&.unlink
      FileUtils.rm_f(renamed) if renamed
    end

    test "run_import refuses pasted text and a file together" do
      file = Tempfile.new([ "people", ".csv" ])
      file.write("Jane,Smith,jane.smith@example.com\n")
      file.close

      post import_madmin_people_path, params: { text: "John Doe <john.doe@example.com>", file: Rack::Test::UploadedFile.new(file.path, "text/csv") }

      assert_response :unprocessable_content
      assert_select ".alert-danger", text: "Paste text or choose a file, not both."
      assert_not Person.exists?(email: "jane.smith@example.com")
    ensure
      file&.unlink
    end

    test "run_import treats a file param that isn't an upload as no file" do
      post import_madmin_people_path, params: { file: "not an upload", text: "Jane Smith <jane.smith@example.com>" }

      assert_response :success
      assert Person.exists?(email: "jane.smith@example.com")
    end

    test "the delete confirmation names the person" do
      get madmin_person_path(@person)

      assert_select "form[action='#{madmin_person_path(@person)}'] button[data-turbo-confirm=?]",
                    "Are you sure you want to delete the person #{@person.full_name}?"
    end

    # Other t calls keep their options (here count:), which the override passes
    # through untouched.
    test "other Madmin translations keep their options" do
      patch madmin_person_path(@person), params: { person: { first_name: "" } }

      assert_select ".alert-danger", text: /There were \d+ errors with your submission/
    end
  end
end

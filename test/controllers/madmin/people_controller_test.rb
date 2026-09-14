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

    test "index shows an Invite button for an active person" do
      get madmin_people_path

      assert_response :success
      assert_match(/>Invite</, response.body)
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
  end
end

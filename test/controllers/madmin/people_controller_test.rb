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

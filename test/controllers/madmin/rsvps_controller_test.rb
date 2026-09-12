require "test_helper"

module Madmin
  class RsvpsControllerTest < ActionDispatch::IntegrationTest
    include ActionMailer::TestHelper

    setup do
      sign_in admins(:one)
      @rsvp = rsvps(:one)
      @rsvp.update!(confirmed: "unconfirmed")
    end

    test "edit renders successfully" do
      get edit_madmin_rsvp_path(@rsvp)

      assert_response :success
    end

    test "new renders successfully" do
      get new_madmin_rsvp_path

      assert_response :success
    end

    test "show renders successfully" do
      get madmin_rsvp_path(@rsvp)

      assert_response :success
    end

    test "create creates an rsvp and redirects to its show page" do
      assert_difference "RSVP.count", 1 do
        post madmin_rsvps_path, params: { rsvp: {
          first_name: "New", last_name: "Rsvp", email: "new.rsvp@example.com",
          show_id: shows(:upcoming).id, response: "yes", seats_reserved: 2
        } }
      end

      assert_redirected_to madmin_rsvp_path(RSVP.last)
    end

    test "create with invalid attributes renders new" do
      assert_no_difference "RSVP.count" do
        post madmin_rsvps_path, params: { rsvp: { first_name: "" } }
      end

      assert_response :unprocessable_content
    end

    test "update updates the rsvp and redirects to its show page" do
      patch madmin_rsvp_path(@rsvp), params: { rsvp: { first_name: "Updated" } }

      assert_equal "Updated", @rsvp.reload.first_name
      assert_redirected_to madmin_rsvp_path(@rsvp)
    end

    test "update with invalid attributes renders edit" do
      patch madmin_rsvp_path(@rsvp), params: { rsvp: { first_name: "" } }

      assert_response :unprocessable_content
      assert_equal "Test", @rsvp.reload.first_name
    end

    test "destroy destroys the rsvp and redirects to the index page" do
      assert_difference "RSVP.count", -1 do
        delete madmin_rsvp_path(@rsvp)
      end

      assert_redirected_to madmin_rsvps_path
    end

    test "confirm confirms the rsvp, emails it, and redirects with a notice" do
      assert_emails 1 do
        patch confirm_madmin_rsvp_path(@rsvp)
      end

      assert_equal "confirmed", @rsvp.reload.confirmed
      assert_redirected_to madmin_rsvps_path
      assert_match(/Confirmed #{Regexp.escape(@rsvp.full_name)}/, flash[:notice])
    end

    test "waitlist waitlists the rsvp, emails it, and redirects with a notice" do
      @rsvp.show.update!(availability: "waitlisted")

      assert_emails 1 do
        patch waitlist_madmin_rsvp_path(@rsvp)
      end

      assert_equal "waitlisted", @rsvp.reload.confirmed
      assert_redirected_to madmin_rsvps_path
      assert_match(/Waitlisted #{Regexp.escape(@rsvp.full_name)}/, flash[:notice])
    end

    test "confirm does not re-email or change an already-confirmed rsvp" do
      @rsvp.update!(confirmed: "confirmed")

      assert_no_emails do
        patch confirm_madmin_rsvp_path(@rsvp)
      end

      assert_equal "confirmed", @rsvp.reload.confirmed
      assert_redirected_to madmin_rsvps_path
      assert_match(/can’t be confirmed/, flash[:alert])
    end

    test "waitlist does not email or change an rsvp when the show can't be waitlisted" do
      assert_no_emails do
        patch waitlist_madmin_rsvp_path(@rsvp)
      end

      assert_equal "unconfirmed", @rsvp.reload.confirmed
      assert_redirected_to madmin_rsvps_path
      assert_match(/can’t be waitlisted/, flash[:alert])
    end

    test "cancel cancels the rsvp and redirects with a notice" do
      @rsvp.update!(confirmed: "confirmed")

      patch cancel_madmin_rsvp_path(@rsvp)

      @rsvp.reload
      assert_equal "no", @rsvp.response
      assert_equal 0, @rsvp.seats_reserved
      assert_redirected_to madmin_rsvps_path
      assert_match(/Cancelled #{Regexp.escape(@rsvp.full_name)}/, flash[:notice])
    end

    test "cancel does not change an already-no rsvp" do
      @rsvp.update!(response: "no")

      patch cancel_madmin_rsvp_path(@rsvp)

      assert_equal "no", @rsvp.reload.response
      assert_redirected_to madmin_rsvps_path
      assert_match(/can’t be cancelled/, flash[:alert])
    end

    test "index shows a Cancel button for an rsvp in the next_show_attendees scope" do
      @rsvp.update!(confirmed: "confirmed")

      get madmin_rsvps_path(scope: "next_show_attendees")

      assert_response :success
      assert_match(/>Cancel</, response.body)
    end

    test "index hides the Cancel button outside the next_show_attendees scope" do
      @rsvp.update!(confirmed: "confirmed")

      get madmin_rsvps_path

      assert_response :success
      assert_no_match(/>Cancel</, response.body)
    end

    test "index shows a Print link in the next_show_attendees scope" do
      get madmin_rsvps_path(scope: "next_show_attendees")

      assert_response :success
      assert_match(/>Print</, response.body)
    end

    test "index hides the Print link outside the next_show_attendees scope" do
      get madmin_rsvps_path

      assert_response :success
      assert_no_match(/>Print</, response.body)
    end

    test "print renders the next show's attendees and totals" do
      @rsvp.update!(confirmed: "confirmed", phone_number: "2125551234")

      get print_madmin_rsvps_path

      assert_response :success
      assert_match(@rsvp.show.name, response.body)
      assert_match(/#{Regexp.escape(@rsvp.full_name)}/, response.body)
      assert_match(/\(212\) 555-1234/, response.body)
      assert_match(/>#{@rsvp.seats_reserved}</, response.body)
      assert_match(%r{>✖</td>\s*<td>✖<}, response.body)
      assert_match(%r{RSVPs</h4>\s*<p>1<}, response.body)
      assert_match(%r{Seats Reserved</h4>\s*<p>2<}, response.body)
    end

    test "print flags an attendee who is on the mailing list and has attended before" do
      @rsvp.update!(confirmed: "confirmed", email: people(:one).email)
      RSVP.create!(first_name: "Past", last_name: "Attendee", email: @rsvp.email, show: shows(:past),
                   response: "yes", confirmed: "confirmed", seats_reserved: 1)

      get print_madmin_rsvps_path

      assert_response :success
      assert_match(%r{>✔</td>\s*<td>✔<}, response.body)
    end

    test "print excludes an rsvp that isn't a confirmed yes for the next show" do
      get print_madmin_rsvps_path

      assert_response :success
      assert_no_match(/#{Regexp.escape(@rsvp.full_name)}/, response.body)
    end

    test "index shows a Confirm button for an rsvp that can be confirmed" do
      get madmin_rsvps_path

      assert_response :success
      assert_match(/>Confirm</, response.body)
      assert_no_match(/>Waitlist</, response.body)
    end

    test "index shows a Waitlist button for an rsvp that can be waitlisted" do
      @rsvp.show.update!(availability: "waitlisted")

      get madmin_rsvps_path

      assert_response :success
      assert_match(/>Waitlist</, response.body)
      assert_no_match(/>Confirm</, response.body)
    end

    test "index hides both buttons once an rsvp is already confirmed" do
      @rsvp.update!(confirmed: "confirmed")

      get madmin_rsvps_path

      assert_response :success
      assert_no_match(/>Confirm</, response.body)
      assert_no_match(/>Waitlist</, response.body)
    end
  end
end

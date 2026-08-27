require "test_helper"

module Madmin
  class RsvpsControllerTest < ActionDispatch::IntegrationTest
    include ActionMailer::TestHelper

    setup do
      sign_in admins(:one)
      @rsvp = rsvps(:one)
      @rsvp.update!(confirmed: "unconfirmed")
    end

    test "confirm confirms the rsvp, emails it, and redirects with a notice" do
      assert_emails 1 do
        patch confirm_madmin_rsvp_path(@rsvp)
      end

      assert_equal "yes", @rsvp.reload.confirmed
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
      @rsvp.update!(confirmed: "yes")

      assert_no_emails do
        patch confirm_madmin_rsvp_path(@rsvp)
      end

      assert_equal "yes", @rsvp.reload.confirmed
      assert_redirected_to madmin_rsvps_path
      assert_match(/can't be confirmed/, flash[:alert])
    end

    test "waitlist does not email or change an rsvp when the show can't be waitlisted" do
      assert_no_emails do
        patch waitlist_madmin_rsvp_path(@rsvp)
      end

      assert_equal "unconfirmed", @rsvp.reload.confirmed
      assert_redirected_to madmin_rsvps_path
      assert_match(/can't be waitlisted/, flash[:alert])
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
      @rsvp.update!(confirmed: "yes")

      get madmin_rsvps_path

      assert_response :success
      assert_no_match(/>Confirm</, response.body)
      assert_no_match(/>Waitlist</, response.body)
    end
  end
end

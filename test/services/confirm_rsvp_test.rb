require "test_helper"

class ConfirmRSVPTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "confirms the rsvp and delivers a confirmation email" do
    rsvp = rsvps(:one)
    rsvp.update!(confirmed: "unconfirmed")

    assert_emails 1 do
      ConfirmRSVP.call(rsvp)
    end

    assert_equal "yes", rsvp.reload.confirmed
  end

  test "does not confirm or email a no rsvp" do
    rsvp = rsvps(:one)
    rsvp.update!(confirmed: "unconfirmed", response: "no", seats_reserved: 0)

    assert_no_emails do
      ConfirmRSVP.call(rsvp)
    end

    assert_equal "unconfirmed", rsvp.reload.confirmed
  end

  test "does not email when confirm! fails to save" do
    rsvp = rsvps(:one)
    rsvp.update!(confirmed: "unconfirmed")
    rsvp.first_name = ""

    assert_no_emails do
      ConfirmRSVP.call(rsvp)
    end

    assert_equal "unconfirmed", rsvp.reload.confirmed
  end
end

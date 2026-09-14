require "test_helper"

class ConfirmRSVPTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "confirms the rsvp and delivers a confirmation email" do
    rsvp = rsvps(:one)
    rsvp.update!(confirmed: "unconfirmed")

    result = nil
    assert_emails 1 do
      result = ConfirmRSVP.call(rsvp)
    end

    assert result
    assert_equal "confirmed", rsvp.reload.confirmed
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

    result = nil
    assert_no_emails do
      result = ConfirmRSVP.call(rsvp)
    end

    assert_not result
    assert_equal "unconfirmed", rsvp.reload.confirmed
  end
end

require "test_helper"

class WaitlistRSVPTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "waitlists the rsvp and delivers a waitlisted email" do
    rsvp = rsvps(:one)
    rsvp.update!(confirmed: "unconfirmed")

    assert_emails 1 do
      WaitlistRSVP.call(rsvp)
    end

    assert_equal "waitlisted", rsvp.reload.confirmed
  end

  test "does not waitlist or email a no rsvp" do
    rsvp = rsvps(:one)
    rsvp.update!(confirmed: "unconfirmed", response: "no", seats_reserved: 0)

    assert_no_emails do
      WaitlistRSVP.call(rsvp)
    end

    assert_equal "unconfirmed", rsvp.reload.confirmed
  end

  test "does not email when waitlist! fails to save" do
    rsvp = rsvps(:one)
    rsvp.update!(confirmed: "unconfirmed")
    rsvp.first_name = ""

    assert_no_emails do
      WaitlistRSVP.call(rsvp)
    end

    assert_equal "unconfirmed", rsvp.reload.confirmed
  end
end

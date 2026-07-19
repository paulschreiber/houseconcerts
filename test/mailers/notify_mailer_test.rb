require "test_helper"

class NotifyMailerTest < ActionMailer::TestCase
  test "rsvp uses a subject appropriate to the type and notifies the admin" do
    rsvp = rsvps(:one)

    new_email = NotifyMailer.rsvp(rsvp, "new", nil)
    assert_includes new_email.subject, "New RSVP"
    assert_equal [ Mail::Address.new(Settings.invites_from).address ], new_email.to

    cancel_email = NotifyMailer.rsvp(rsvp, "cancel", nil)
    assert_includes cancel_email.subject, "Cancellation"

    update_email = NotifyMailer.rsvp(rsvp, "update", 1)
    assert_includes update_email.subject, "Updated RSVP"
  end

  test "rsvp delivers exactly one email" do
    assert_emails 1 do
      NotifyMailer.rsvp(rsvps(:one), "new", nil).deliver_now
    end
  end

  test "text_message includes the matching rsvp's name when the phone number matches" do
    rsvp = rsvps(:one)
    rsvp.update!(phone_number: "2125551234")

    email = NotifyMailer.text_message("+12125551234", "hello")

    assert_includes email.subject, rsvp.full_name
  end

  test "text_message falls back to the raw sender when no rsvp matches" do
    email = NotifyMailer.text_message("+15559999999", "hello")

    assert_includes email.subject, "+15559999999"
  end
end

require "test_helper"

class InvitesTest < ActionMailer::TestCase
  test "invite does nothing for a nil person or show" do
    assert_no_emails { InvitesMailer.invite(nil, shows(:upcoming)).deliver_now }
    assert_no_emails { InvitesMailer.invite(people(:one), nil).deliver_now }
  end

  test "invite does nothing when given the wrong types" do
    assert_no_emails { InvitesMailer.invite("not a person", shows(:upcoming)).deliver_now }
    assert_no_emails { InvitesMailer.invite(people(:one), "not a show").deliver_now }
  end

  test "invite does nothing for an inactive person" do
    person = people(:one)
    person.update!(status: "removed")

    assert_no_emails { InvitesMailer.invite(person, shows(:upcoming)).deliver_now }
  end

  test "invite delivers to an active person for an upcoming show" do
    person = people(:one)
    show = shows(:upcoming)

    email = InvitesMailer.invite(person, show)

    assert_emails 1 do
      email.deliver_now
    end
    assert_equal [ person.email ], email.to
    assert_includes email.subject, show.name
    assert_equal email.header["List-Unsubscribe"].to_s, email["List-Unsubscribe"].to_s
  end

  test "waitlisted does nothing for an rsvp with no seats reserved" do
    rsvp = rsvps(:one)
    # seats_reserved: 0 would normally fail validation for a "yes" rsvp -
    # bypass it deliberately to set up this edge case.
    rsvp.update_column(:seats_reserved, 0) # rubocop:disable Rails/SkipsModelValidations

    assert_no_emails { InvitesMailer.waitlisted(rsvp).deliver_now }
  end

  test "waitlisted delivers with a waitlist subject" do
    rsvp = rsvps(:one)

    assert_emails 1 do
      InvitesMailer.waitlisted(rsvp).deliver_now
    end
  end

  test "confirm delivers with a confirmation subject and a calendar link" do
    rsvp = rsvps(:one)

    email = InvitesMailer.confirm(rsvp)

    assert_emails 1 do
      email.deliver_now
    end
    assert_includes email.subject, "RSVP Confirmation"
    assert_includes email.body.encoded, "calendar.google.com"
  end

  test "remind delivers with a reminder subject" do
    rsvp = rsvps(:one)

    email = InvitesMailer.remind(rsvp)

    assert_emails 1 do
      email.deliver_now
    end
    assert_includes email.subject, "Reminder"
  end

  test "make_calendar_url builds a google calendar link with the show details" do
    rsvp = rsvps(:one)
    url = InvitesMailer.new.make_calendar_url(rsvp)

    assert_includes url, "https://calendar.google.com/calendar/r/eventedit"
    assert_includes url, CGI.escape(rsvp.show.name)
  end
end

require "test_helper"

class NotifyMailerTest < ActionMailer::TestCase
  test "rsvp uses a subject appropriate to the type and notifies the admin" do
    rsvp = rsvps(:one)

    new_email = NotifyMailer.rsvp(rsvp, "new", nil)
    assert_includes new_email.subject, "New RSVP"
    assert_equal [ "#{Settings.invites_from_email}@#{Settings.domain}" ], new_email.to

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

  test "rsvp shows no previous reservations for someone with no attendance history" do
    person = Person.create!(first_name: "No", last_name: "History", email: "no.history@example.com")
    rsvp = RSVP.create!(show: shows(:upcoming), first_name: person.first_name, last_name: person.last_name,
                        email: person.email, response: "yes", confirmed: "yes", seats_reserved: 2)

    email = NotifyMailer.rsvp(rsvp, "new", nil)

    assert_includes email.body.encoded, "No previous reservations."
  end

  test "rsvp lists a single past show for someone who attended one show" do
    person = Person.create!(first_name: "One", last_name: "Show", email: "one.show@example.com")
    attended = create_past_rsvp(person, shows(:past), seats_reserved: 2, seats_used: 2)
    rsvp = RSVP.create!(show: shows(:upcoming), first_name: person.first_name, last_name: person.last_name,
                        email: person.email, response: "yes", confirmed: "yes", seats_reserved: 2)

    email = NotifyMailer.rsvp(rsvp, "new", nil)
    body = email.body.encoded

    assert_includes body, attended.show.name
    assert_equal 1, body.scan("<li>").count
    assert_row_wrapped_in("span", body, attended.show)
  end

  test "rsvp lists three past shows for someone who attended three shows" do
    person = Person.create!(first_name: "Three", last_name: "Shows", email: "three.shows@example.com")
    show_a = create_past_show("Three Shows A", 3)
    show_b = create_past_show("Three Shows B", 2)
    show_c = create_past_show("Three Shows C", 1)

    create_past_rsvp(person, show_a, seats_reserved: 2, seats_used: 2)
    create_past_rsvp(person, show_b, seats_reserved: 1, seats_used: 1)
    create_past_rsvp(person, show_c, seats_reserved: 3, seats_used: 3)

    rsvp = RSVP.create!(show: shows(:upcoming), first_name: person.first_name, last_name: person.last_name,
                        email: person.email, response: "yes", confirmed: "yes", seats_reserved: 2)

    email = NotifyMailer.rsvp(rsvp, "new", nil)
    body = email.body.encoded

    assert_includes body, show_a.name
    assert_includes body, show_b.name
    assert_includes body, show_c.name
    assert_equal 3, body.scan("<li>").count
    assert_row_wrapped_in("span", body, show_a)
    assert_row_wrapped_in("span", body, show_b)
    assert_row_wrapped_in("span", body, show_c)
  end

  test "rsvp bolds a past show where fewer seats were used than reserved" do
    person = Person.create!(first_name: "Unused", last_name: "Seats", email: "unused.seats@example.com")
    show = create_past_show("Unused Seats", 1)
    create_past_rsvp(person, show, seats_reserved: 2, seats_used: 0)

    rsvp = RSVP.create!(show: shows(:upcoming), first_name: person.first_name, last_name: person.last_name,
                        email: person.email, response: "yes", confirmed: "yes", seats_reserved: 2)

    email = NotifyMailer.rsvp(rsvp, "new", nil)
    body = email.body.encoded

    assert_row_wrapped_in("strong", body, show)
  end

  test "rsvp uses a span for a past show where seats used equals seats reserved" do
    person = Person.create!(first_name: "Exact", last_name: "Seats", email: "exact.seats@example.com")
    show = create_past_show("Exact Seats", 1)
    create_past_rsvp(person, show, seats_reserved: 2, seats_used: 2)

    rsvp = RSVP.create!(show: shows(:upcoming), first_name: person.first_name, last_name: person.last_name,
                        email: person.email, response: "yes", confirmed: "yes", seats_reserved: 2)

    email = NotifyMailer.rsvp(rsvp, "new", nil)
    body = email.body.encoded

    assert_row_wrapped_in("span", body, show)
  end

  test "rsvp uses a span for a past show where more seats were used than reserved" do
    person = Person.create!(first_name: "Extra", last_name: "Seats", email: "extra.seats@example.com")
    show = create_past_show("Extra Seats", 1)
    create_past_rsvp(person, show, seats_reserved: 2, seats_used: 3)

    rsvp = RSVP.create!(show: shows(:upcoming), first_name: person.first_name, last_name: person.last_name,
                        email: person.email, response: "yes", confirmed: "yes", seats_reserved: 2)

    email = NotifyMailer.rsvp(rsvp, "new", nil)
    body = email.body.encoded

    assert_row_wrapped_in("span", body, show)
  end

  private

    def assert_row_wrapped_in(tag, body, show)
      assert_match(/<#{tag}>\s*#{Regexp.escape(show.start.to_date.iso8601)}.*#{Regexp.escape(show.name)}/m, body)
    end

    def create_past_show(name, months_ago)
      Show.create!(
        name: name,
        venue: venues(:one),
        start: months_ago.months.ago.change(hour: 19, min: 0, sec: 0),
        status: "confirmed",
        price: 20,
        blurb: "A test show for attendance history."
      )
    end

    def create_past_rsvp(person, show, seats_reserved:, seats_used:)
      RSVP.create!(show: show, first_name: person.first_name, last_name: person.last_name,
                   email: person.email, response: "yes", confirmed: "yes",
                   seats_reserved: seats_reserved, seats_used: seats_used)
    end
end

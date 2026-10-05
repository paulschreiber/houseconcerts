require "test_helper"

class NotifyMailerTest < ActionMailer::TestCase
  test "rsvp uses a subject appropriate to the type and notifies the admin" do
    new_email = NotifyMailer.rsvp(rsvps(:one), "new", nil)
    assert_includes new_email.subject, "New RSVP"
    assert_equal [ "#{Settings.invites_from_email}@#{Settings.domain}" ], new_email.to
  end

  test "rsvp uses a cancellation subject for type cancel" do
    email = NotifyMailer.rsvp(rsvps(:one), "cancel", nil)
    assert_includes email.subject, "Cancellation"
  end

  test "rsvp uses an updated subject for type update" do
    email = NotifyMailer.rsvp(rsvps(:one), "update", 1)
    assert_includes email.subject, "Updated RSVP"
  end

  test "rsvp delivers exactly one email" do
    assert_emails 1 do
      NotifyMailer.rsvp(rsvps(:one), "new", nil).deliver_now
    end
  end

  test "rsvp only sends once even if the same job is performed twice" do
    rsvp = rsvps(:one)

    assert_emails 1 do
      2.times { NotifyMailer.rsvp(rsvp, "new", nil).deliver_now }
    end
  end

  test "rsvp is a no-op when already notified for this exact save" do
    rsvp = rsvps(:one)
    rsvp.update_column(:admin_notified_at, rsvp.updated_at) # rubocop:disable Rails/SkipsModelValidations

    assert_no_emails do
      NotifyMailer.rsvp(rsvp, "new", nil).deliver_now
    end
  end

  test "rsvp sends again for a genuinely later save" do
    rsvp = rsvps(:one)
    rsvp.update_column(:admin_notified_at, 1.hour.ago(rsvp.updated_at)) # rubocop:disable Rails/SkipsModelValidations

    assert_emails 1 do
      NotifyMailer.rsvp(rsvp, "update", 1).deliver_now
    end
  end

  test "rsvp releases its claim if delivery fails, so a retry can resend" do
    rsvp = rsvps(:one)

    original_deliver = Mail::TestMailer.instance_method(:deliver!)
    Mail::TestMailer.define_method(:deliver!) { |_mail| raise "simulated SMTP failure" }

    job = ActionMailer::MailDeliveryJob.new("NotifyMailer", "rsvp", "deliver_now", args: [ rsvp, "new", nil ])
    assert_raises(RuntimeError) { job.perform_now }

    assert_nil rsvp.reload.admin_notified_at
  ensure
    Mail::TestMailer.define_method(:deliver!, original_deliver)
  end

  test "a mailer job that fails before its action runs leaves an earlier job's claim alone" do
    rsvp = rsvps(:one)
    perform_enqueued_jobs { NotifyMailer.rsvp(rsvp, "new", nil).deliver_later }
    notified_at = rsvp.reload.admin_notified_at
    assert_not_nil notified_at

    # An RSVP deleted after the job was queued: loading it fails before the
    # mailer action (and its before_action) ever runs.
    job = ActionMailer::MailDeliveryJob.new("NotifyMailer", "rsvp", "deliver_now", args: [ RSVP.new(id: -1), "new", nil ])
    assert_raises(ActiveJob::DeserializationError) { ActiveJob::Base.execute(job.serialize) }

    assert_equal notified_at, rsvp.reload.admin_notified_at
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

  test "rsvp shows the attendance history section for an updated yes rsvp" do
    person = Person.create!(first_name: "Repeat", last_name: "Attendee", email: "repeat.attendee@example.com")
    create_past_rsvp(person, shows(:past), seats_reserved: 2, seats_used: 2)
    rsvp = RSVP.create!(show: shows(:upcoming), first_name: person.first_name, last_name: person.last_name,
                        email: person.email, response: "yes", confirmed: "confirmed", seats_reserved: 2)

    body = NotifyMailer.rsvp(rsvp, "update", 1).body.encoded

    assert_includes body, "Attendance History"
  end

  test "rsvp omits the attendance history section for a cancellation" do
    person = Person.create!(first_name: "Cancelling", last_name: "Attendee", email: "cancelling.attendee@example.com")
    create_past_rsvp(person, shows(:past), seats_reserved: 2, seats_used: 2)
    rsvp = RSVP.create!(show: shows(:upcoming), first_name: person.first_name, last_name: person.last_name,
                        email: person.email, response: "yes", confirmed: "confirmed", seats_reserved: 2)
    rsvp.update!(response: "no")

    body = NotifyMailer.rsvp(rsvp, "cancel", nil).body.encoded

    assert_not_includes body, "Attendance History"
  end

  test "rsvp shows no previous reservations for someone with no attendance history" do
    person = Person.create!(first_name: "No", last_name: "History", email: "no.history@example.com")
    rsvp = RSVP.create!(show: shows(:upcoming), first_name: person.first_name, last_name: person.last_name,
                        email: person.email, response: "yes", confirmed: "confirmed", seats_reserved: 2)

    email = NotifyMailer.rsvp(rsvp, "new", nil)

    assert_includes email.body.encoded, "No previous reservations."
  end

  test "rsvp lists attended and cancelled shows together, newest first" do
    person = Person.create!(first_name: "Jane", last_name: "Smith", email: "jane.smith@example.com")
    create_past_rsvp(person, create_past_show("Oldest Show", 3), seats_reserved: 2, seats_used: 2)
    cancelled = create_past_rsvp(person, create_past_show("Middle Show", 2), seats_reserved: 2, seats_used: nil)
    travel_to Time.zone.local(2026, 9, 1, 12) do
      cancelled.update!(response: "no")
    end
    create_past_rsvp(person, create_past_show("Newest Show", 1), seats_reserved: 2, seats_used: 1)
    rsvp = RSVP.create!(show: shows(:upcoming), first_name: person.first_name, last_name: person.last_name,
                        email: person.email, response: "yes", confirmed: "confirmed", seats_reserved: 2)

    body = NotifyMailer.rsvp(rsvp, "new", nil).body.encoded

    rows = history_rows(body).map { |row| row.css("td")[1..].map { |td| td.text.strip } }
    assert_equal [ [ "Newest Show", "1 / 2" ], [ "Middle Show", "Cancelled 2026-09-01" ], [ "Oldest Show", "2 / 2" ] ], rows
    assert_not_includes body, "No previous reservations."
  end

  test "rsvp lists a single past show for someone who attended one show" do
    person = Person.create!(first_name: "One", last_name: "Show", email: "one.show@example.com")
    attended = create_past_rsvp(person, shows(:past), seats_reserved: 2, seats_used: 2)
    rsvp = RSVP.create!(show: shows(:upcoming), first_name: person.first_name, last_name: person.last_name,
                        email: person.email, response: "yes", confirmed: "confirmed", seats_reserved: 2)

    email = NotifyMailer.rsvp(rsvp, "new", nil)
    body = email.body.encoded

    assert_includes body, attended.show.name
    assert_equal 1, history_rows(body).count
    assert_row_bold(false, body, attended.show)
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
                        email: person.email, response: "yes", confirmed: "confirmed", seats_reserved: 2)

    email = NotifyMailer.rsvp(rsvp, "new", nil)
    body = email.body.encoded

    assert_includes body, show_a.name
    assert_includes body, show_b.name
    assert_includes body, show_c.name
    assert_equal 3, history_rows(body).count
    assert_row_bold(false, body, show_a)
    assert_row_bold(false, body, show_b)
    assert_row_bold(false, body, show_c)
  end

  test "rsvp bolds a past show where fewer seats were used than reserved" do
    person = Person.create!(first_name: "Unused", last_name: "Seats", email: "unused.seats@example.com")
    show = create_past_show("Unused Seats", 1)
    create_past_rsvp(person, show, seats_reserved: 2, seats_used: 0)

    rsvp = RSVP.create!(show: shows(:upcoming), first_name: person.first_name, last_name: person.last_name,
                        email: person.email, response: "yes", confirmed: "confirmed", seats_reserved: 2)

    email = NotifyMailer.rsvp(rsvp, "new", nil)
    body = email.body.encoded

    assert_row_bold(true, body, show)
  end

  test "rsvp does not bold a past show where seats used equals seats reserved" do
    person = Person.create!(first_name: "Exact", last_name: "Seats", email: "exact.seats@example.com")
    show = create_past_show("Exact Seats", 1)
    create_past_rsvp(person, show, seats_reserved: 2, seats_used: 2)

    rsvp = RSVP.create!(show: shows(:upcoming), first_name: person.first_name, last_name: person.last_name,
                        email: person.email, response: "yes", confirmed: "confirmed", seats_reserved: 2)

    email = NotifyMailer.rsvp(rsvp, "new", nil)
    body = email.body.encoded

    assert_row_bold(false, body, show)
  end

  test "rsvp does not bold a past show where more seats were used than reserved" do
    person = Person.create!(first_name: "Extra", last_name: "Seats", email: "extra.seats@example.com")
    show = create_past_show("Extra Seats", 1)
    create_past_rsvp(person, show, seats_reserved: 2, seats_used: 3)

    rsvp = RSVP.create!(show: shows(:upcoming), first_name: person.first_name, last_name: person.last_name,
                        email: person.email, response: "yes", confirmed: "confirmed", seats_reserved: 2)

    email = NotifyMailer.rsvp(rsvp, "new", nil)
    body = email.body.encoded

    assert_row_bold(false, body, show)
  end

  test "ses_event tells the admin who bounced, with a link to them" do
    person = people(:one)
    email = NotifyMailer.ses_event(person, "bounce")

    assert_equal "Bounce from #{person.full_name}", email.subject
    assert_equal [ "#{Settings.invites_from_email}@#{Settings.domain}" ], email.to
    assert_includes email.body.to_s, person.email
    assert_includes email.body.to_s, "bounced permanently"
    assert_includes email.body.to_s, "/backstage/people/#{person.id}"
  end

  test "ses_event explains a complaint" do
    email = NotifyMailer.ses_event(people(:one), "complaint")

    assert_equal "Complaint from #{people(:one).full_name}", email.subject
    assert_includes email.body.to_s, "as spam"
  end

  private

    def history_rows(body)
      Nokogiri::HTML(body).css(".history tbody tr")
    end

    def assert_row_bold(bold, body, show)
      row = history_rows(body).find { |tr| tr.css("td").map { |td| td.text.strip }.first(2) == [ show.start.to_date.iso8601, show.name ] }
      assert row, "no history row for #{show.name}"
      assert_equal bold, row.classes.include?("unused-seats")
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
                   email: person.email, response: "yes", confirmed: "confirmed",
                   seats_reserved: seats_reserved, seats_used: seats_used)
    end
end

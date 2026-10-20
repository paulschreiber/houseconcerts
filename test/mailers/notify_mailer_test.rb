require "test_helper"

class NotifyMailerTest < ActionMailer::TestCase
  include BatchTestHelpers

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

  test "failed_batch_items summarizes failed invite recipients (Person)" do
    batch_run = create_run(status: "completed", total_count: 2, sent_count: 1, failed_count: 1)
    person = Person.create!(first_name: "Failed", last_name: "Invite", email: "failed.invite@example.com", status: "active")
    batch_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")
    batch_run.batch_run_items.create!(recipient: Person.create!(first_name: "Sent", last_name: "Ok", email: "sent.ok@example.com", status: "active"), status: "sent", sent_at: Time.current)

    email = NotifyMailer.failed_batch_items(batch_run)

    assert_includes email.subject, "1 failed invites send"
    assert_includes email.subject, show.name
    assert_equal [ "#{Settings.invites_from_email}@#{Settings.domain}" ], email.to
    body = email.body.encoded
    assert_includes body, person.email
    assert_includes body, "boom"
    assert_not_includes body, "sent.ok@example.com"
  end

  test "failed_batch_items summarizes failed remind recipients (RSVP)" do
    batch_run = create_run(kind: "remind", status: "completed", failed_count: 1)
    rsvp = rsvps(:one)
    batch_run.batch_run_items.create!(recipient: rsvp, status: "failed", error_message: "SMS failed")

    email = NotifyMailer.failed_batch_items(batch_run)

    assert_includes email.subject, "1 failed reminders send"
    body = email.body.encoded
    assert_includes body, rsvp.email
    assert_includes body, "SMS failed"
  end

  test "failed_batch_items shows a placeholder instead of raising when a recipient was deleted" do
    batch_run = create_run(status: "completed", failed_count: 1)
    person = Person.create!(first_name: "Deleted", last_name: "Recipient", email: "deleted-recipient@example.com", status: "active")
    batch_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")
    person.destroy!

    email = NotifyMailer.failed_batch_items(batch_run)

    assert_includes email.body.encoded, "(recipient deleted)"
  end

  test "failed_batch_items delivers exactly one email" do
    batch_run = create_run(status: "completed", failed_count: 1)
    person = Person.create!(first_name: "Failed", last_name: "Invite", email: "failed.invite2@example.com", status: "active")
    batch_run.batch_run_items.create!(recipient: person, status: "failed", error_message: "boom")

    assert_emails 1 do
      NotifyMailer.failed_batch_items(batch_run).deliver_now
    end
  end

  test "auto_reminders_started counts confirmed attendees and lists unconfirmed rsvps" do
    batch_run = create_run(kind: "remind", status: "pending", automatic: true)
    RSVP.create!(show:, email: "unconfirmed@example.com", first_name: "Jane", last_name: "Smith", response: "yes", seats_reserved: 2)
    RSVP.create!(show:, email: "waitlisted@example.com", first_name: "John", last_name: "Smith", response: "yes", seats_reserved: 1, confirmed: "waitlisted")

    email = NotifyMailer.auto_reminders_started(batch_run)

    assert_equal "Reminders started for #{show.name}", email.subject
    assert_equal [ "#{Settings.invites_from_email}@#{Settings.domain}" ], email.to
    body = email.body.encoded
    assert_includes body, "1 confirmed attendee (2 seats)"
    assert_includes body, "Jane Smith (unconfirmed@example.com) — 2 seats"
    assert_includes body, "John Smith (waitlisted@example.com) — 1 seat, waitlisted"
  end

  test "auto_reminders_started only says automatically for an automatic run" do
    automatic = NotifyMailer.auto_reminders_started(create_run(kind: "remind", status: "pending", automatic: true))
    assert_includes automatic.body.encoded, "started automatically"

    resumed = NotifyMailer.auto_reminders_started(BatchRun.new(show:, kind: "remind", automatic: false))
    assert_not_includes resumed.body.encoded, "automatically"
  end

  test "auto_reminders_started says when no one is confirmed" do
    rsvps(:one).update!(confirmed: "unconfirmed")
    batch_run = create_run(kind: "remind", status: "pending", automatic: true)

    body = NotifyMailer.auto_reminders_started(batch_run).body.encoded

    assert_includes body, "has no confirmed attendees, so no reminders went out"
    assert_includes body, rsvps(:one).email
  end

  test "auto_reminders_failed gives the reason and whether it will be retried" do
    final = NotifyMailer.auto_reminders_failed(show, "Send the initial invites first.", will_retry: false)
    retrying = NotifyMailer.auto_reminders_failed(show, "Try again later.", will_retry: true)

    assert_equal "Reminders not sent for #{show.name}", final.subject
    assert_includes final.body.encoded, "Send the initial invites first."
    assert_includes final.body.encoded, "They won’t be tried again automatically. Send them from the show page."
    assert_includes retrying.body.encoded, "They’ll be tried again automatically until they start."
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

  test "rsvp shows a dash, not a no-show, for a past show whose seats used weren't recorded" do
    person = Person.create!(first_name: "Unrecorded", last_name: "Seats", email: "unrecorded.seats@example.com")
    show = create_past_show("Unrecorded Seats", 1)
    create_past_rsvp(person, show, seats_reserved: 2, seats_used: nil)

    rsvp = RSVP.create!(show: shows(:upcoming), first_name: person.first_name, last_name: person.last_name,
                        email: person.email, response: "yes", confirmed: "confirmed", seats_reserved: 2)

    body = NotifyMailer.rsvp(rsvp, "new", nil).body.encoded

    assert_row_bold(false, body, show)
    assert_equal "— / 2", history_row(body, show).css("td").last.text.strip
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

    def history_row(body, show)
      row = history_rows(body).find { |tr| tr.css("td").map { |td| td.text.strip }.first(2) == [ show.start.to_date.iso8601, show.name ] }
      assert row, "no history row for #{show.name}"
      row
    end

    def assert_row_bold(bold, body, show)
      assert_equal bold, history_row(body, show).classes.include?("unused-seats")
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

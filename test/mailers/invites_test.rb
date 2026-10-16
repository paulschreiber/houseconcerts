require "test_helper"

class InvitesTest < ActionMailer::TestCase
  test "invite does nothing for a nil person or show" do
    assert_no_emails { InvitesMailer.with(person: nil, show: shows(:upcoming)).invite.deliver_now }
    assert_no_emails { InvitesMailer.with(person: people(:one), show: nil).invite.deliver_now }
  end

  test "invite does nothing for an inactive person" do
    person = people(:one)
    person.update!(status: "removed")

    assert_no_emails { InvitesMailer.with(person: person, show: shows(:upcoming)).invite.deliver_now }
  end

  test "invite delivers to an active person for an upcoming show" do
    person = people(:one)
    show = shows(:upcoming)

    email = InvitesMailer.with(person: person, show: show).invite

    assert_emails 1 do
      email.deliver_now
    end
    assert_equal [ person.email ], email.to
    assert_equal [ "#{Settings.invites_from_email}@#{Settings.domain}" ], email.from
    assert_equal "#{Settings.invites_from_first_name} #{Settings.invites_from_last_name}", email[:from].display_names.first
    assert_match %r{>\s*#{Settings.invites_from_first_name}</p>}, email.body.decoded
    assert_includes email.subject, show.name
    unsub_url = Rails.application.routes.url_helpers.unsubscribe_url(uniqid: person.uniqid, host: "example.com")
    assert_equal "<#{unsub_url}>", email["List-Unsubscribe"].to_s
    assert_equal "List-Unsubscribe=One-Click", email["List-Unsubscribe-Post"].to_s
  end

  test "invite includes an open-tracking pixel keyed to the person's uniqid" do
    person = people(:one)
    show = shows(:upcoming)

    email = InvitesMailer.with(person: person, show: show).invite

    expected_src = tracking_pixel_url(tag: "#{show.slug}:invite", uniqid: person.uniqid, kind: "person")
    assert_includes email.body.encoded, %(src="#{expected_src}")
  end

  test "invite fills its fixed layout with the show's current revision and the person's links" do
    person = people(:one)
    show = shows(:upcoming)
    show.invite_messages.create!(intro: "Second **intro**. [Count me in][rsvp_yes]", about: "Second *bio*.")

    body = InvitesMailer.with(person: person, show: show).invite.body.encoded

    assert_includes body, "Hi #{person.first_name},"
    assert_includes body, "Second <strong>intro</strong>."
    yes_url = Rails.application.routes.url_helpers.rsvp_response_url(slug: show.slug, uniqid: person.uniqid, response: :yes, host: "example.com")
    assert_includes body, %(<a href="#{yes_url}">Count me in</a>)
    assert_includes body, %(<ul class="summary">)
    assert_includes body, "Yes! I’m in for #{show.name}!"
    assert_includes body, "A bit about #{show.name}"
    assert_includes body, "Second <em>bio</em>."
    assert_includes body, "instantly unsubscribe"
    assert_not_includes body, "Next up"
  end

  test "invite sends the revision it's given" do
    show = shows(:upcoming)
    first = invite_messages(:upcoming)
    show.invite_messages.create!(intro: "Second intro", about: "Second bio")

    body = InvitesMailer.with(person: people(:one), show: show, invite_message: first).invite.body.encoded

    assert_includes body, "Next up"
    assert_not_includes body, "Second intro"
  end

  test "invite raises when the show has no invite written" do
    error = assert_raises(ArgumentError) { InvitesMailer.with(person: people(:one), show: shows(:sold_out)).invite.deliver_now }
    assert_equal "#{shows(:sold_out).name} has no invite written", error.message
  end

  test "a test invite is marked in its subject and tracked apart from invites" do
    person = people(:one)
    show = shows(:upcoming)

    email = InvitesMailer.with(person: person, show: show, email_type: "test").invite

    assert_equal "[Test] You’re invited: #{show.event_name} (#{show.start_date_short})", email.subject
    assert_includes email.body.encoded, tracking_pixel_url(tag: "#{show.slug}:test", uniqid: person.uniqid, kind: "person")
  end

  test "invite_preview renders an unsaved revision for a sample person, with links that go nowhere" do
    show = shows(:upcoming)
    message = show.invite_messages.new(intro: "Draft [yes][rsvp_yes]", about: "Draft bio")

    email = InvitesMailer.with(show: show, invite_message: message).invite_preview
    body = email.body.encoded

    assert_equal [ "jane.smith@example.com" ], email.to
    assert_includes body, "Hi Jane,"
    assert_includes body, %(<a href="#rsvp_yes">yes</a>)
    assert_includes body, %(href="#unsubscribe")
    assert_not_includes body, "<img"
  end

  test "invite has a Gmail go-to action that opens the person's RSVP form" do
    person = people(:one)
    show = shows(:upcoming)

    data = ld_json_in(html_body(InvitesMailer.with(person: person, show: show).invite))

    assert_equal "EmailMessage", data["@type"]
    assert_equal "ViewAction", data.dig("potentialAction", "@type")
    assert_equal "Reserve seats", data.dig("potentialAction", "name")
    routes = Rails.application.routes.url_helpers
    assert_equal routes.modify_rsvp_url(slug: show.slug, uniqid: person.uniqid), data.dig("potentialAction", "url")
  end

  test "waitlisted does nothing for an rsvp that changed to no after it was queued" do
    rsvp = rsvps(:one)
    rsvp.update!(response: "no")

    assert_no_emails { InvitesMailer.with(rsvp: rsvp).waitlisted.deliver_now }
  end

  test "waitlisted delivers with a waitlist subject" do
    rsvp = rsvps(:one)

    assert_emails 1 do
      InvitesMailer.with(rsvp: rsvp).waitlisted.deliver_now
    end
  end

  test "waitlisted includes an open-tracking pixel keyed to the rsvp's uniqid" do
    rsvp = rsvps(:one)

    email = InvitesMailer.with(rsvp: rsvp).waitlisted

    expected_src = tracking_pixel_url(tag: "#{rsvp.show.slug}:waitlist", uniqid: rsvp.uniqid, kind: "rsvp")
    assert_includes email.body.encoded, %(src="#{expected_src}")
  end

  test "waitlisted is a no-op if it has already sent for this rsvp" do
    rsvp = rsvps(:one)
    rsvp.update_column(:waitlist_emailed_at, Time.current) # rubocop:disable Rails/SkipsModelValidations

    assert_no_emails { InvitesMailer.with(rsvp: rsvp).waitlisted.deliver_now }
  end

  test "confirm only sends once even if the same job is performed twice" do
    rsvp = rsvps(:one)

    assert_emails 1 do
      2.times { InvitesMailer.with(rsvp: rsvp).confirm.deliver_now }
    end
  end

  { "confirm" => :confirmation_emailed_at, "waitlisted" => :waitlist_emailed_at }.each do |action, claim|
    test "#{action} releases its claim if delivery fails, so a retry can resend" do
      rsvp = rsvps(:one)

      job = ActionMailer::MailDeliveryJob.new("InvitesMailer", action, "deliver_now", params: { rsvp: rsvp }, args: [])
      with_stubbed_instance_method(Mail::TestMailer, :deliver!, ->(_mail) { raise "simulated SMTP failure" }) do
        assert_raises(RuntimeError) { job.perform_now }
      end

      assert_nil rsvp.reload.public_send(claim)
    end
  end

  test "confirm delivers with a confirmation subject" do
    rsvp = rsvps(:one)

    email = InvitesMailer.with(rsvp: rsvp).confirm

    assert_emails 1 do
      email.deliver_now
    end
    assert_includes email.subject, "RSVP Confirmation"
  end

  test "confirm attaches the show as an .ics event with the full address and the guest's link" do
    rsvp = rsvps(:one)
    show = rsvp.show

    attachment = InvitesMailer.with(rsvp: rsvp).confirm.attachments.sole

    assert_equal show.ics_filename, attachment.filename
    assert_equal "text/calendar", attachment.mime_type
    assert_nil attachment.content_type_parameters["method"]
    calendar = Icalendar::Calendar.parse(attachment.decoded).sole
    assert_equal "PUBLISH", calendar.ip_method
    event = calendar.events.sole
    rsvp_url = Rails.application.routes.url_helpers.modify_rsvp_url(slug: show.slug, uniqid: rsvp.uniqid)
    assert_equal "event-#{show.slug}@#{Settings.domain}", event.uid
    assert_equal show.venue.full_address_calendar, event.location
    assert_equal rsvp_url, event.url.to_s
    assert_includes event.description, rsvp_url
  end

  test "confirm raises for an incomplete show, leaving the confirmation unsent" do
    rsvp = rsvps(:one)
    rsvp.show.artists = []

    error = assert_raises(ArgumentError) { InvitesMailer.with(rsvp: rsvp).confirm.deliver_now }
    assert_equal "#{rsvp.show.name} isn’t complete: it needs to be confirmed, with an artist", error.message
  end

  test "confirm includes an open-tracking pixel keyed to the rsvp's uniqid" do
    rsvp = rsvps(:one)

    email = InvitesMailer.with(rsvp: rsvp).confirm

    expected_src = tracking_pixel_url(tag: "#{rsvp.show.slug}:confirm", uniqid: rsvp.uniqid, kind: "rsvp")
    assert_includes html_body(email), %(src="#{expected_src}")
  end

  test "confirm embeds the reservation as parseable JSON-LD, with the full address" do
    rsvp = rsvps(:one)

    data = confirm_ld_json(rsvp)

    assert_equal "EventReservation", data["@type"]
    assert_equal rsvp.uniqid, data["reservationNumber"]
    assert_equal "https://schema.org/ReservationConfirmed", data["reservationStatus"]
    assert_equal "MusicEvent", data.dig("reservationFor", "@type")
    assert_equal "123 Main St", data.dig("reservationFor", "location", "address", "streetAddress")
    assert_equal "11201", data.dig("reservationFor", "location", "address", "postalCode")
  end

  test "confirm's JSON-LD links to modifying (as Update RSVP) and cancelling the reservation" do
    rsvp = rsvps(:one)

    data = confirm_ld_json(rsvp)

    routes = Rails.application.routes.url_helpers
    modify_url = routes.modify_rsvp_url(slug: rsvp.show.slug, uniqid: rsvp.uniqid)
    assert_equal modify_url, data["modifyReservationUrl"]
    assert_equal({ "@type" => "EditAction", "name" => "Update RSVP", "target" => modify_url }, data["potentialAction"])
    assert_equal routes.rsvp_response_url(slug: rsvp.show.slug, uniqid: rsvp.uniqid, response: :no), data["cancelReservationUrl"]
  end

  test "confirm escapes markup in JSON-LD values so they can't close the script tag" do
    rsvp = rsvps(:one)
    rsvp.update_column(:first_name, "</script><b>x") # rubocop:disable Rails/SkipsModelValidations

    html = html_body(InvitesMailer.with(rsvp: rsvp).confirm)

    assert_not_includes html, "</script><b>x"
    assert_includes ld_json_in(html).dig("underName", "name"), "</script><b>x"
  end

  test "confirm sends only to the rsvp's email even if the name contains addresses" do
    rsvp = rsvps(:one)
    rsvp.update_column(:first_name, 'Bob", attacker@evil.com, "X') # rubocop:disable Rails/SkipsModelValidations

    email = InvitesMailer.with(rsvp: rsvp).confirm

    assert_equal [ rsvp.email ], email.to
  end

  test "confirm is a no-op if it has already sent for this rsvp" do
    rsvp = rsvps(:one)
    rsvp.update_column(:confirmation_emailed_at, Time.current) # rubocop:disable Rails/SkipsModelValidations

    assert_no_emails { InvitesMailer.with(rsvp: rsvp).confirm.deliver_now }
  end

  test "remind delivers with a reminder subject" do
    rsvp = rsvps(:one)

    email = InvitesMailer.with(rsvp: rsvp).remind

    assert_emails 1 do
      email.deliver_now
    end
    assert_includes email.subject, "Reminder"
  end

  test "remind includes an open-tracking pixel keyed to the rsvp's uniqid" do
    rsvp = rsvps(:one)

    email = InvitesMailer.with(rsvp: rsvp).remind

    expected_src = tracking_pixel_url(tag: "#{rsvp.show.slug}:remind", uniqid: rsvp.uniqid, kind: "rsvp")
    assert_includes email.body.encoded, %(src="#{expected_src}")
  end

  test "rsvp_updated tells the guest what changed and links to their RSVP" do
    rsvp = rsvps(:one)

    email = InvitesMailer.with(rsvp: rsvp, previous: { response: "yes", seats: 2 }, current: { response: "no", seats: 0 }).rsvp_updated
    body = email.body.decoded

    assert_equal [ rsvp.email ], email.to
    assert_includes email.subject, "Your RSVP was updated"
    assert_includes body, "this email address (#{rsvp.email})"
    assert_includes body, "Before: Attending, 2 seats"
    assert_includes body, "Now: Not attending"
    assert_includes body, "/rsvps/show/#{rsvp.show.slug}/#{rsvp.uniqid}"
  end

  test "rsvp_updated reports the change it was sent for, even if the RSVP changed again since" do
    rsvp = rsvps(:one) # now yes, 2 seats

    body = InvitesMailer.with(rsvp: rsvp, previous: { response: "yes", seats: 3 }, current: { response: "no", seats: 0 }).rsvp_updated.body.decoded

    assert_includes body, "Before: Attending, 3 seats"
    assert_includes body, "Now: Not attending"
  end

  test "rsvp_change_requested sends the guest their link and says nothing changed" do
    rsvp = rsvps(:one)

    email = InvitesMailer.with(rsvp: rsvp, seats: 2).rsvp_change_requested
    body = email.body.decoded

    assert_equal [ rsvp.email ], email.to
    assert_includes email.subject, "Changing your RSVP"
    assert_includes body, "this email address (#{rsvp.email})"
    assert_includes body, "nothing has changed yet: you still have 2 seats"
    assert_includes body, "/rsvps/show/#{rsvp.show.slug}/#{rsvp.uniqid}"
  end

  test "the RSVP emails are signed with the sender's first name" do
    mailer = InvitesMailer.with(rsvp: rsvps(:one), previous: { response: "yes", seats: 2 }, current: { response: "no", seats: 0 }, seats: 2)

    %i[confirm waitlisted remind rsvp_updated rsvp_change_requested].each do |action|
      email = mailer.public_send(action)
      # confirm is multipart, with its calendar attachment.
      html = (email.html_part || email).body.decoded
      assert_match %r{>\s*#{Settings.invites_from_first_name}</p>}, html, action
    end
  end

  test "rsvp_change_requested states the seats as of the request" do
    body = InvitesMailer.with(rsvp: rsvps(:one), seats: 4).rsvp_change_requested.body.decoded

    assert_includes body, "you still have 4 seats"
  end

  private

    def html_body(email)
      email.html_part ? email.html_part.decoded : email.body.decoded
    end

    def ld_json_in(html)
      JSON.parse(Nokogiri::HTML(html).at_css('script[type="application/ld+json"]').text)
    end

    # The confirmation email is sent at most once per RSVP, so each test
    # renders it once.
    def confirm_ld_json(rsvp)
      ld_json_in(html_body(InvitesMailer.with(rsvp: rsvp).confirm))
    end

    def tracking_pixel_url(tag:, uniqid:, kind:)
      Rails.application.routes.url_helpers.open_tracking_url(tag: tag, uniqid: uniqid, kind: kind, host: "example.com")
    end
end

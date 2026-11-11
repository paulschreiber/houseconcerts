require "test_helper"

class ShowTest < ActiveSupport::TestCase
  test "fixture is valid" do
    assert shows(:upcoming).valid?
    assert shows(:past).valid?
  end

  test "a blank price gets one error" do
    show = shows(:upcoming)
    show.price = nil

    assert_not show.valid?
    assert_equal [ "Enter a price for the show." ], show.errors[:price]
  end

  test "an unknown status or availability is invalid, not an error" do
    show = shows(:upcoming)
    show.status = "postponed"
    show.availability = "unknown"

    assert_not show.valid?
    assert_equal [ "Enter a valid show status." ], show.errors[:status]
    assert_equal [ "Enter a valid show availability." ], show.errors[:availability]
  end

  test "requires a venue that exists" do
    show = shows(:upcoming)
    show.venue_id = 0

    assert_not show.valid?
    assert_includes show.errors[:venue], "Select a venue."
  end

  test "upcoming scope includes only shows that haven't happened yet" do
    assert_includes Show.upcoming, shows(:upcoming)
    assert_not_includes Show.upcoming, shows(:past)
  end

  test "past/occurred scope includes only shows that already happened" do
    assert_includes Show.past, shows(:past)
    assert_not_includes Show.past, shows(:upcoming)
  end

  test "occurred? reflects whether the show's start is in the past" do
    assert shows(:past).occurred?
    assert_not shows(:upcoming).occurred?
  end

  test "status predicate methods reflect the status attribute" do
    show = Show.new(status: "confirmed")
    assert show.confirmed?
    assert_not show.cancelled?

    show.status = "cancelled"
    assert show.cancelled?
    assert_not show.confirmed?
  end

  test "set_end_time fills in end based on show_duration when blank" do
    show = Show.new(
      name: "Duration Test",
      venue: venues(:one),
      start: 1.month.from_now,
      status: "confirmed",
      price: 20
    )
    show.valid?

    assert_equal Settings.show_duration.hours, show.end - show.start
  end

  test "moving the start moves the end, keeping the show's length" do
    show = shows(:upcoming)
    show.update!(end: show.start + 3.hours)

    show.update!(start: show.start + 1.day)

    assert_equal 3.hours, show.end - show.start
  end

  test "an end changed along with the start is kept" do
    show = shows(:upcoming)
    new_end = show.start + 1.day + 4.hours

    show.update!(start: show.start + 1.day, end: new_end)

    assert_equal new_end, show.end
  end

  test "messages name what's wrong, without the attribute in front" do
    show = shows(:upcoming)
    show.assign_attributes(name: "", price: Settings.show.max_price + 1, end: show.start - 1.hour)

    assert_not show.valid?
    assert_equal [ "Enter a show name.", "The end must be after the start",
                   "The price cannot be more than $#{Settings.show.max_price}" ].sort, show.errors.full_messages.sort
  end

  test "a price below the minimum, or with cents, says so" do
    show = shows(:upcoming)

    show.price = Settings.show.min_price - 1
    assert_not show.valid?
    assert_equal [ "The price must be at least $#{Settings.show.min_price}" ], show.errors[:price]

    show.price = 20.5
    assert_not show.valid?
    assert_equal [ "Enter the price in whole dollars" ], show.errors[:price]
  end

  test "a blank start is an error, not a crash" do
    show = Show.new(name: "Jane Smith Live", venue: venues(:one), price: 20)

    assert_not show.valid?
    assert_equal [ "Enter a valid start date/time." ], show.errors[:start]
  end

  test "an invalid start says so" do
    show = shows(:upcoming)
    show.start = "not a date"

    assert_not show.valid?
    assert_equal [ "Enter a valid start date/time." ], show.errors[:start]
  end

  test "requires end to be after start" do
    show = Show.new(
      name: "Invalid Show",
      venue: venues(:one),
      start: 1.month.from_now,
      end: 1.month.from_now - 1.hour,
      status: "confirmed",
      price: 20
    )
    assert_not show.valid?
    assert_includes show.errors.attribute_names, :end
  end

  test "self.next and self.previous return the nearest upcoming/past show" do
    assert_equal shows(:upcoming), Show.next
    assert_equal shows(:past), Show.previous
  end

  test "next_show? is true only for the nearest upcoming show" do
    assert shows(:upcoming).next_show?
    assert_not shows(:past).next_show?
  end

  test "next_show? is false for every show when there is no upcoming show" do
    Show.upcoming.update_all(status: "cancelled") # rubocop:disable Rails/SkipsModelValidations

    assert_not shows(:upcoming).next_show?
    assert_not shows(:past).next_show?
  end

  test "attendees returns confirmed yes rsvps" do
    assert_includes shows(:upcoming).attendees, rsvps(:one)
  end

  test "invites_sent? reflects whether an invite batch run has completed and actually sent at least one invite" do
    show = shows(:upcoming)
    assert_not show.invites_sent?

    show.batch_runs.create!(kind: "invite", status: "completed", total_count: 1, sent_count: 1)

    assert show.invites_sent?
  end

  test "invites_sent? is false for a completed invite batch run that had zero eligible recipients" do
    show = shows(:upcoming)
    show.batch_runs.create!(kind: "invite", status: "completed", total_count: 0, sent_count: 0)

    assert_not show.invites_sent?
  end

  test "invites_sent? ignores batch runs of other kinds" do
    show = shows(:upcoming)
    show.batch_runs.create!(kind: "remind", status: "completed", total_count: 1, sent_count: 1)

    assert_not show.invites_sent?
  end

  test "invites_sent? is false while the invite batch run is still pending or running" do
    show = shows(:upcoming)
    show.batch_runs.create!(kind: "invite", status: "pending", total_count: 0)

    assert_not show.invites_sent?
  end

  test "can_confirm_rsvps? and can_waitlist_rsvps? across every status/availability combination" do
    show = shows(:upcoming)
    statuses = %w[confirmed unconfirmed cancelled]
    availabilities = %w[available waitlisted sold_out]

    statuses.product(availabilities).each do |status, availability|
      show.status = status
      show.availability = availability

      expected_can_confirm = status == "confirmed" && availability == "available"
      expected_can_waitlist = status == "confirmed" && availability == "waitlisted"
      combo = "status=#{status} availability=#{availability}"

      assert_equal expected_can_confirm, show.can_confirm_rsvps?, "can_confirm_rsvps? wrong for #{combo}"
      assert_equal expected_can_waitlist, show.can_waitlist_rsvps?, "can_waitlist_rsvps? wrong for #{combo}"
    end
  end

  test "can_confirm_rsvps? needs a complete show, since confirming sends the confirmation" do
    show = shows(:upcoming)
    show.artists = []

    assert_not show.can_confirm_rsvps?
  end

  test "ics_filename is the show's name, as a slug, and its date" do
    show = shows(:upcoming)
    show.name = "Jane Smith & Café Trio"

    assert_equal "jane-smith-cafe-trio-#{show.start.to_date.iso8601}.ics", show.ics_filename
  end

  test "artists come in the order they were added" do
    show = shows(:upcoming)
    created_first = Artist.create!(name: "Created First")
    created_second = Artist.create!(name: "Created Second")
    added = [ created_second, created_first ]
    show.artists << added

    assert_equal [ artists(:one), *added ], show.reload.artists.to_a
    assert_equal [ artists(:one), *added ], Show.includes(:artists).find(show.id).artists.to_a
  end

  test "dated_name combines the name with an ISO-formatted date" do
    show = shows(:upcoming)

    assert_equal "#{show.name} (#{show.start.to_date.iso8601})", show.dated_name
  end

  test "dated_name does not crash when start is nil" do
    show = shows(:upcoming)
    show.start = nil

    assert_equal "#{show.name} ()", show.dated_name
  end

  test "destroying a show removes its artist_shows in a single bulk delete, not one per row" do
    show = Show.create!(name: "Multi-artist show", venue: venues(:one), price: 20,
                        artists: [ artists(:one), Artist.create!(name: "Second Artist") ],
                        start: 2.months.from_now, end: 2.months.from_now + 2.hours)

    assert_queries_match(/\ADELETE FROM `artists_shows`/, count: 1) do
      show.destroy
    end

    assert_equal 0, ArtistShow.where(show_id: show.id).count
  end

  test "accepting_rsvps? only for confirmed shows that haven't happened" do
    show = shows(:upcoming)
    assert_predicate show, :accepting_rsvps?

    show.status = "cancelled"
    assert_not show.accepting_rsvps?

    show.status = "unconfirmed"
    assert_not show.accepting_rsvps?

    assert_not shows(:past).accepting_rsvps?
  end

  # The venue holds 10 seats and the waitlist Settings.show.waitlist_capacity
  # more. The upcoming show already has 2 seats from a fixture RSVP.
  test "availability moves from available to waitlisted to sold out as seats are booked" do
    show = shows(:upcoming)
    small_venue

    book(show, 7)
    assert_equal "available", show.reload.availability

    book(show, 1)
    assert_equal "waitlisted", show.reload.availability

    book(show, Settings.show.waitlist_capacity - 1)
    assert_equal "waitlisted", show.reload.availability

    book(show, 1)
    assert_equal "sold_out", show.reload.availability
  end

  test "availability counts waitlisted seats, so waitlisting an RSVP doesn't change it" do
    show = shows(:upcoming)
    small_venue
    book(show, 8).first.waitlist!

    assert_equal "waitlisted", show.reload.availability
  end

  test "availability returns to available when seats free up" do
    show = shows(:upcoming)
    small_venue
    parties = book(show, 8)
    assert_equal "waitlisted", show.reload.availability

    parties.first.cancel!
    assert_equal "available", show.reload.availability

    book(show, 4).last.destroy
    assert_equal "available", show.reload.availability
  end

  test "an admin's sold out is recalculated when RSVPs change" do
    show = shows(:upcoming)
    show.update!(availability: "sold_out")

    rsvps(:one).cancel!

    assert_equal "available", show.reload.availability
  end

  test "a show close to its start goes straight to sold out when full, with no waitlist" do
    show = shows(:upcoming)
    small_venue
    start_soon(show)

    book(show, 7)
    assert_equal "available", show.reload.availability

    book(show, 1)
    assert_equal "sold_out", show.reload.availability
  end

  test "a show close to its start doesn't go back to a better availability" do
    show = shows(:upcoming)
    small_venue
    parties = book(show, 8)
    assert_equal "waitlisted", show.reload.availability
    start_soon(show)

    parties.first.cancel!
    assert_equal "waitlisted", show.reload.availability

    show.update_columns(availability: "sold_out") # rubocop:disable Rails/SkipsModelValidations
    show.update_availability
    assert_equal "sold_out", show.reload.availability
  end

  test "a waitlisted show close to its start sells out once the waitlist is full" do
    show = shows(:upcoming)
    small_venue
    book(show, 8)
    start_soon(show)

    book(show, Settings.show.waitlist_capacity)

    assert_equal "sold_out", show.reload.availability
  end

  test "availability is left alone for cancelled and past shows" do
    cancelled = shows(:upcoming)
    cancelled.update!(status: "cancelled", availability: "sold_out")
    past = shows(:past)
    past.update_columns(availability: "sold_out") # rubocop:disable Rails/SkipsModelValidations

    cancelled.update_availability
    past.update_availability

    assert_equal "sold_out", cancelled.reload.availability
    assert_equal "sold_out", past.reload.availability
  end

  test "changing a show's venue recalculates its availability" do
    show = shows(:upcoming)
    book(show, 8)
    small = create_venue(name: "Small Venue", capacity: 10)

    show.update!(venue: small)

    assert_equal "waitlisted", show.reload.availability
  end

  test "rsvps.awaiting_confirmation returns unconfirmed and waitlisted yes rsvps" do
    show = shows(:upcoming)
    unconfirmed = RSVP.create!(show:, email: "unconfirmed@example.com", first_name: "Jane", last_name: "Smith", response: "yes", seats_reserved: 1)
    waitlisted = RSVP.create!(show:, email: "waitlisted@example.com", first_name: "Jane", last_name: "Smith", response: "yes", seats_reserved: 1, confirmed: "waitlisted")
    RSVP.create!(show:, email: "no@example.com", first_name: "Jane", last_name: "Smith", response: "no")

    assert_equal [ unconfirmed, waitlisted ].sort, show.rsvps.awaiting_confirmation.sort
  end

  test "rsvps.holding_seats returns confirmed and unconfirmed yes rsvps, not waitlisted ones" do
    show = shows(:upcoming)
    confirmed = RSVP.create!(show:, email: "confirmed@example.com", first_name: "Jane", last_name: "Smith", response: "yes", seats_reserved: 1, confirmed: "confirmed")
    unconfirmed = RSVP.create!(show:, email: "unconfirmed@example.com", first_name: "Jane", last_name: "Smith", response: "yes", seats_reserved: 1)
    waitlisted = RSVP.create!(show:, email: "waitlisted@example.com", first_name: "Jane", last_name: "Smith", response: "yes", seats_reserved: 1, confirmed: "waitlisted")
    declined = RSVP.create!(show:, email: "no@example.com", first_name: "Jane", last_name: "Smith", response: "no")

    holding = show.rsvps.holding_seats.where(id: [ confirmed, unconfirmed, waitlisted, declined ])
    assert_equal [ confirmed, unconfirmed ].sort, holding.sort
  end

  test "reminder_time is the configured hour, the configured days before the show" do
    show = Show.new(start: Time.zone.parse("2026-12-05 19:30"))

    assert_equal Time.zone.parse("2026-12-04 13:00"), show.reminder_time
  end

  test "reminder_time stays at the configured hour across daylight saving changes" do
    fall_back = Show.new(start: Time.zone.parse("2026-11-02 19:00"))
    spring_forward = Show.new(start: Time.zone.parse("2027-03-15 19:00"))

    assert_equal "2026-11-01 13:00:00 -0500", fall_back.reminder_time.to_s
    assert_equal "2027-03-14 13:00:00 -0400", spring_forward.reminder_time.to_s
  end

  test "reminder_time_label formats the reminder time" do
    assert_equal "Fri, Dec 4 at 1:00 pm", Show.new(start: Time.zone.parse("2026-12-05 19:30")).reminder_time_label
  end

  test "reminder_time is nil without a start" do
    assert_nil Show.new.reminder_time
  end

  test "doors and door_time are nil without a start" do
    assert_nil Show.new.doors
    assert_nil Show.new.door_time
  end

  test "reminders_due includes upcoming shows past their reminder time that haven't been tried" do
    show = shows(:upcoming)

    travel_to show.reminder_time - 1.minute do
      assert_not_includes Show.reminders_due, show
    end

    travel_to show.reminder_time do
      assert_includes Show.reminders_due, show

      show.update_column(:auto_remind_attempted_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
      assert_not_includes Show.reminders_due, show
    end
  end

  test "changing start resets the automatic reminder attempt" do
    show = shows(:upcoming)
    show.update_column(:auto_remind_attempted_at, 1.hour.ago) # rubocop:disable Rails/SkipsModelValidations

    show.update!(start: show.start + 1.day, end: nil)

    assert_nil show.reload.auto_remind_attempted_at
    assert_in_delta Time.current, show.rescheduled_at, 1.second
  end

  test "other changes keep the automatic reminder attempt" do
    show = shows(:upcoming)
    attempted_at = 1.hour.ago.change(usec: 0)
    show.update!(auto_remind_attempted_at: attempted_at)

    show.update!(name: "Renamed Show")

    assert_equal attempted_at, show.reload.auto_remind_attempted_at
    assert_nil show.rescheduled_at
  end

  test "reminders_handled? counts running and completed remind runs, not pending ones" do
    show = shows(:upcoming)
    run = show.batch_runs.create!(kind: "remind", status: "pending")
    assert_not show.reminders_handled?

    run.update!(status: "running")
    assert show.reminders_handled?

    run.update!(status: "completed")
    assert show.reminders_handled?
  end

  test "reminders_handled? ignores remind runs from before the show was rescheduled" do
    show = shows(:upcoming)
    show.batch_runs.create!(kind: "remind", status: "completed", created_at: 1.day.ago)

    show.update!(start: show.start + 1.week, end: nil)

    assert_not show.reminders_handled?
  end

  test "auto_remind_pending? until the show is tried, handled, cancelled or over" do
    show = shows(:upcoming)
    assert_predicate show, :auto_remind_pending?

    assert_not shows(:past).auto_remind_pending?

    show.status = "cancelled"
    assert_not show.auto_remind_pending?

    show.status = "confirmed"
    show.auto_remind_attempted_at = Time.current
    assert_not show.auto_remind_pending?

    show.auto_remind_attempted_at = nil
    show.batch_runs.create!(kind: "remind", status: "completed")
    assert_not show.auto_remind_pending?
  end

  test "event_name is the show's name followed by house concert" do
    assert_equal "Test Upcoming Show house concert", shows(:upcoming).event_name
  end

  test "complete? needs a confirmed show with at least one artist" do
    show = shows(:upcoming)
    assert show.complete?

    show.status = "unconfirmed"
    assert_not show.complete?, "unconfirmed"

    show.reload.artists = []
    assert_not show.complete?, "no artists"
  end

  private

    # Moves the show inside the window where it gets no waitlist.
    def start_soon(show)
      soon = (Settings.show.availability_cutoff_hours - 1).hours.from_now
      show.update_columns(start: soon, end: soon + 2.hours) # rubocop:disable Rails/SkipsModelValidations
    end
end

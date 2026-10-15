require "test_helper"

class ShowTest < ActiveSupport::TestCase
  test "fixture is valid" do
    assert shows(:upcoming).valid?
    assert shows(:past).valid?
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

  test "duration returns the length of the show in seconds" do
    assert_equal 2.hours.to_i, shows(:upcoming).duration
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

  test "summary combines the name with an ISO-formatted date" do
    show = shows(:upcoming)

    assert_equal "#{show.name} (#{show.start.to_date.iso8601})", show.summary
  end

  test "summary does not crash when start is nil" do
    show = shows(:upcoming)
    show.start = nil

    assert_equal "#{show.name} ()", show.summary
  end

  test "destroying a show removes its artist_shows in a single bulk delete, not one per row" do
    show = Show.create!(name: "Multi-artist show", venue: venues(:one), price: 20,
                        artists: [ artists(:one), Artist.create!(name: "Second Artist") ],
                        start: 2.months.from_now, end: 2.months.from_now + 2.hours)

    delete_queries = 0
    callback = ->(*, payload) { delete_queries += 1 if payload[:sql]&.match?(/\ADELETE FROM `artists_shows`/) }

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      show.destroy
    end

    assert_equal 1, delete_queries
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

  test "unconfirmed_rsvps returns unconfirmed and waitlisted yes rsvps" do
    show = shows(:upcoming)
    unconfirmed = RSVP.create!(show:, email: "unconfirmed@example.com", first_name: "Jane", last_name: "Smith", response: "yes", seats_reserved: 1)
    waitlisted = RSVP.create!(show:, email: "waitlisted@example.com", first_name: "Jane", last_name: "Smith", response: "yes", seats_reserved: 1, confirmed: "waitlisted")
    RSVP.create!(show:, email: "no@example.com", first_name: "Jane", last_name: "Smith", response: "no")

    assert_equal [ unconfirmed, waitlisted ].sort, show.unconfirmed_rsvps.sort
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
end

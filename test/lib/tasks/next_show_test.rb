require "test_helper"

class NextShowRakeTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    load_rake_tasks
    %w[invite invite_one invite_unopened invite_count attendees rsvps unconfirmed opens confirm].each do |task|
      Rake::Task["next_show:#{task}"].reenable
    end
  end

  test "invite_count reports how many people can be emailed" do
    Person.create!(first_name: "New", last_name: "Person", email: "invite-count@example.com", status: "active")

    out, = capture_io { Rake::Task["next_show:invite_count"].invoke }

    assert_includes out, "Can email 1 people."
  end

  test "invite emails eligible people for the next show" do
    person = Person.create!(first_name: "New", last_name: "Person", email: "invite@example.com", status: "active")

    out = nil
    assert_emails 1 do
      out, = capture_io { Rake::Task["next_show:invite"].invoke }
    end
    assert_includes out, person.email_address_with_name
  end

  test "invite excludes people who already RSVPd for the show" do
    person = Person.create!(first_name: "Already", last_name: "Rsvpd", email: "already-rsvpd@example.com", status: "active")
    RSVP.create!(show: shows(:upcoming), email: person.email, first_name: "Already", last_name: "Rsvpd", response: "yes", seats_reserved: 1)

    assert_no_emails do
      capture_io { Rake::Task["next_show:invite"].invoke }
    end
  end

  test "invite_one emails a specific person for the next show" do
    person = Person.create!(first_name: "Direct", last_name: "Invite", email: "direct-invite@example.com", status: "active")

    assert_emails 1 do
      capture_io { Rake::Task["next_show:invite_one"].invoke(person.email) }
    end
  end

  test "invite_one exits when the person cannot be found" do
    assert_raises(SystemExit) do
      capture_io { Rake::Task["next_show:invite_one"].invoke("nonexistent@example.com") }
    end
  end

  test "invite_unopened excludes people who already opened an invite for the show" do
    show = shows(:upcoming)
    opened = Person.create!(first_name: "Already", last_name: "Opened", email: "opened-invite@example.com", status: "active")
    not_opened = Person.create!(first_name: "Not", last_name: "Opened", email: "fresh-invite@example.com", status: "active")
    Open.create!(tag: "#{show.slug}:invite-abc", email: opened.email, open: true)

    out = nil
    assert_emails 1 do
      out, = capture_io { Rake::Task["next_show:invite_unopened"].invoke }
    end
    assert_includes out, not_opened.email
    assert_not_includes out, opened.email
  end

  test "attendees lists confirmed attendees of the next show" do
    rsvp = rsvps(:one)

    out, = capture_io { Rake::Task["next_show:attendees"].invoke }

    assert_includes out, rsvp.full_name
    assert_includes out, "Total: 2 seats / 1 reservations"
  end

  test "rsvps summarizes rsvp status counts for the next show" do
    out, = capture_io { Rake::Task["next_show:rsvps"].invoke }

    assert_includes out, "Total: 2 seats (2 confirmed 0 waitlisted) / 1 reservations (1 confirmed 0 waitlisted) / 0 declines"
  end

  test "unconfirmed lists rsvps awaiting confirmation for the next show" do
    rsvp = RSVP.create!(show: shows(:upcoming), email: "unconfirmed@example.com", first_name: "Un", last_name: "Confirmed", response: "yes", seats_reserved: 1)

    out, = capture_io { Rake::Task["next_show:unconfirmed"].invoke }

    assert_includes out, rsvp.email
    assert_includes out, "Total: 1 seats (1 unconfirmed 0 waitlisted) / 1 reservations (1 unconfirmed 0 waitlisted)"
  end

  test "opens counts unique email opens for the next show" do
    show = shows(:upcoming)
    Open.create!(tag: "#{show.slug}:invite-1", email: "a@example.com", open: true)
    Open.create!(tag: "#{show.slug}:invite-2", email: "a@example.com", open: true)
    Open.create!(tag: "#{show.slug}:confirm-1", email: "b@example.com", open: true)

    out, = capture_io { Rake::Task["next_show:opens"].invoke }

    assert_includes out, "Opens: 2 emails 3 opens"
  end

  test "confirm confirms unconfirmed rsvps and delivers confirmation emails" do
    rsvp = RSVP.create!(show: shows(:upcoming), email: "to-confirm@example.com", first_name: "To", last_name: "Confirm", response: "yes", seats_reserved: 1)

    assert_emails 1 do
      capture_io { Rake::Task["next_show:confirm"].invoke }
    end
    assert rsvp.reload.confirmed?
  end
end

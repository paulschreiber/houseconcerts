def print_confirmation(count)
  puts "Sent #{count} #{'email'.pluralize(count)}."
end

def run_batch(show, kind, noun)
  # Recipients are computed and enqueued in the background (BatchRunFanOutJob),
  # so the count isn't known yet here -- check the show's madmin page for progress.
  StartBatchRun.call(show: show, kind: kind)
  puts "Started sending #{noun.pluralize} for #{show.name}."
rescue StartBatchRun::AlreadyInProgress
  puts "A #{kind} batch is already in progress for #{show.name}; not starting another."
end

namespace :next_show do
  desc "Send invites for next show"
  task invite: :environment do
    show = Show.next
    if show.nil?
      puts "No upcoming shows found"
      exit
    end

    run_batch(show, "invite", "invite")
  end

  desc "Send invites for next show to one person"
  task :invite_one, [ :email ] => [ :environment ] do |_, args|
    email = args[:email]
    unless email
      puts "Please enter an email address"
      exit
    end

    person = Person.find_by(email: email)
    if person.nil?
      puts "Could not find anyone with the email #{email}"
      exit
    end

    show = Show.next
    if show.nil?
      puts "No upcoming shows found"
      exit
    end

    unless person.active?
      puts "Email #{email} is not active"
      exit
    end

    puts "Emailing #{person.email_address_with_name}..."
    InvitePerson.call(person, show)
  end

  desc "Send invites for next show to people who have not opened the invitation"
  task invite_unopened: :environment do
    show = Show.next
    if show.nil?
      puts "No upcoming shows found"
      exit
    end

    run_batch(show, "invite_unopened", "invite")
  end

  desc "Count invites for next show"
  task invite_count: :environment do
    show = Show.next
    if show.nil?
      puts "No upcoming shows found"
      exit
    end

    people = Person.includes(:venue_groups)
                   .where(venue_groups: { id: Settings.default_venue_group }, status: "active")
                   .where("email NOT IN (SELECT email FROM rsvps WHERE show_id = ?)", show.id)

    puts "Can email #{people.size} people."
  end

  desc "Show attendees for next show"
  task attendees: :environment do
    show = Show.next
    if show.nil?
      puts "No upcoming shows found"
      exit
    end

    seats_reserved = 0
    reservations = 0
    show.attendees.order(:id).each do |rsvp|
      puts "#{rsvp.created_at.to_date} #{rsvp.seats_reserved} #{rsvp.person_exists? ? ' ' : '✖'} #{rsvp.phone_number.to_s.ljust(14)} #{rsvp.full_name}"
      seats_reserved += rsvp.seats_reserved
      reservations += 1
    end
    puts "Total: #{seats_reserved} seats / #{reservations} reservations"
  end

  desc "Show RSVPs for next show"
  task rsvps: :environment do
    show = Show.next
    if show.nil?
      puts "No upcoming shows found"
      exit
    end

    seats_reserved = 0
    reservations = 0
    confirmed = 0
    confirmed_seats = 0
    waitlisted = 0
    waitlisted_seats = 0
    declines = 0
    RSVP.where(show: show).order(:id).each do |rsvp|
      if rsvp.confirmed?
        status = "✔"
      elsif rsvp.waitlisted?
        status = "w"
      elsif rsvp.yes?
        status = "✖"
      else
        status = " "
      end
      puts "#{rsvp.created_at.to_date} #{rsvp.response.rjust(3)}#{status} #{rsvp.seats_reserved} #{rsvp.email}"

      seats_reserved += rsvp.seats_reserved if rsvp.yes?
      reservations += 1 if rsvp.yes?
      declines += 1 if rsvp.no?
      if rsvp.confirmed?
        confirmed += 1
        confirmed_seats += rsvp.seats_reserved
      end
      if rsvp.waitlisted?
        waitlisted += 1
        waitlisted_seats += rsvp.seats_reserved
      end
    end
    puts "Total: #{seats_reserved} seats (#{confirmed_seats} confirmed #{waitlisted_seats} waitlisted) / #{reservations} reservations (#{confirmed} confirmed #{waitlisted} waitlisted) / #{declines} declines"
  end

  desc "Show Unconfirmed RSVPs for next show"
  task unconfirmed: :environment do
    show = Show.next
    if show.nil?
      puts "No upcoming shows found"
      exit
    end

    reservations = 0
    unconfirmed = 0
    unconfirmed_seats = 0
    waitlisted = 0
    waitlisted_seats = 0

    RSVP.where(show: show, response: "yes", confirmed: %w[unconfirmed waitlisted]).order(:id).each do |rsvp|
      if rsvp.waitlisted?
        status = "w"
      else
        status = " "
      end
      puts "#{rsvp.created_at.to_date} #{rsvp.response.rjust(3)}#{status} #{rsvp.seats_reserved} #{rsvp.email}"

      reservations += 1 if rsvp.yes?
      if rsvp.waitlisted?
        waitlisted += 1
        waitlisted_seats += rsvp.seats_reserved
      else
        unconfirmed += 1
        unconfirmed_seats += rsvp.seats_reserved
      end
    end
    seats = waitlisted_seats + unconfirmed_seats

    puts "Total: #{seats} seats (#{unconfirmed_seats} unconfirmed #{waitlisted_seats} waitlisted) / #{reservations} reservations (#{unconfirmed} unconfirmed #{waitlisted} waitlisted)"
  end

  desc "Show Email opens for next show"
  task opens: :environment do
    show = Show.next
    if show.nil?
      puts "No upcoming shows found"
      exit
    end

    emails_seen = []

    opens = Open.where("tag LIKE ?", "#{show.slug}%").order(:created_at)
    opens.each do |open|
      next if emails_seen.include?(open.email)

      puts "#{open.created_at.to_date} #{open.tag[(show.slug.length + 1)..]} #{open.email}"
      emails_seen << open.email
    end
    puts "Opens: #{emails_seen.size} emails #{opens.size} opens"
  end

  desc "Confirm RSVPs for next show"
  task confirm: :environment do
    show = Show.next
    if show.nil?
      puts "No upcoming shows found"
      exit
    end

    unless show.confirmed?
      puts "Next show is not confirmed"
      exit
    end

    rsvps = []

    if show.available?
      rsvps = RSVP.where(show: show, response: "yes", confirmed: %w[unconfirmed waitlisted])
      rsvps.each do |rsvp|
        puts "Emailing #{rsvp.email_address_with_name}..."
        ConfirmRSVP.call(rsvp)
      end
    elsif show.waitlisted?
      rsvps = RSVP.where(show: show, response: "yes", confirmed: [ "unconfirmed" ])
      rsvps.each do |rsvp|
        puts "Emailing #{rsvp.email_address_with_name}..."
        WaitlistRSVP.call(rsvp)
      end
    end
    print_confirmation(rsvps.size)
  end

  desc "Remind RSVPs for next show"
  task remind: :environment do
    show = Show.next
    if show.nil?
      puts "No upcoming shows found"
      exit
    end

    run_batch(show, "remind", "reminder")
  end
end

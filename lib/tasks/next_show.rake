def print_confirmation(count)
  puts "Sent #{count} #{'email'.pluralize(count)}."
end

namespace :next_show do
  desc "Send invites for next show"
  task invite: :environment do
    show = Show.next
    if show.nil?
      puts "No upcoming shows found"
      exit
    end

    people = Person.includes(:venue_groups)
                   .where(venue_groups: { id: HC_CONFIG.default_venue_group }, status: "active")
                   .where("email NOT IN (SELECT email FROM rsvps WHERE show_id = ?)", show.id)
                   .order(:last_name, :first_name)

    people.each do |p|
      puts "Emailing #{p.email_address_with_name}..."
      InvitesMailer.invite(p, show).deliver_now
    rescue Net::SMTPServerBusy => e
      puts "Failed to email #{p.email_address_with_name} [#{e.message}]"
    end
    print_confirmation(people.size)
  end

  desc "Send invites for next show to one person"
  task :invite_one, [ :email ] => [ :environment ] do |_, args|
    email = args[:email]
    unless email
      puts "Please enter an email address"
      exit
    end

    person = Person.where(email: email).first
    if person.nil?
      puts "Could not find anyone with the email #{email}"
      exit
    end

    show = Show.next
    if show.nil?
      puts "No upcoming shows found"
      exit
    end

    puts "Emailing #{person.email_address_with_name}..."
    InvitesMailer.invite(person, show).deliver_now
  end

  desc "Send invites for next show to people who have not opened the invitation"
  task invite_unopened: :environment do
    show = Show.next
    if show.nil?
      puts "No upcoming shows found"
      exit
    end

    people = Person.includes(:venue_groups)
                   .where(venue_groups: { id: HC_CONFIG.default_venue_group }, status: "active")
                   .where("email NOT IN (SELECT email FROM rsvps WHERE show_id = ?)", show.id)
                   .where("email NOT IN (SELECT email FROM opens WHERE tag LIKE ?)", "#{show.slug}:invite%")
                   .order(:last_name, :first_name)

    people.each do |p|
      puts "Emailing #{p.email_address_with_name}..."
      InvitesMailer.invite(p, show).deliver_now
    rescue Net::SMTPServerBusy => e
      puts "Failed to email #{p.email_address_with_name} [#{e.message}]"
    end
    print_confirmation(people.size)
  end

  desc "Count invites for next show"
  task invite_count: :environment do
    show = Show.next
    if show.nil?
      puts "No upcoming shows found"
      exit
    end

    people = Person.includes(:venue_groups)
                   .where(venue_groups: { id: HC_CONFIG.default_venue_group }, status: "active")
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
    RSVP.where(show: show, response: "yes").order(:id).each do |rsvp|
      puts "#{rsvp.created_at.to_date} #{rsvp.seats_reserved} #{rsvp.full_name}"
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
        is_confirmed = "✔"
      elsif rsvp.waitlisted?
        is_confirmed = "w"
      elsif rsvp.yes?
        is_confirmed = "✖"
      else
        is_confirmed = " "
      end
      puts "#{rsvp.created_at.to_date} #{rsvp.response.rjust(3)}#{is_confirmed} #{rsvp.seats_reserved} #{rsvp.email}"

      seats_reserved += rsvp.seats_reserved
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

      puts "#{open.created_at.to_date} #{open.tag[show.slug.length + 1..]} #{open.email}"
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

    if show.confirmed?
      rsvps = RSVP.where(show: show, response: "yes").where("(confirmed != 'yes' OR confirmed IS NULL)")
      rsvps.each do |rsvp|
        puts "Emailing #{rsvp.email_address_with_name}..."
        InvitesMailer.confirm(rsvp).deliver_now
        rsvp.confirm!
      end
    elsif show.waitlisted?
      rsvps = RSVP.where(show: show, response: "yes").where("( (confirmed != 'yes' AND confirmed != 'waitlisted') OR confirmed IS NULL)")
      rsvps.each do |rsvp|
        puts "Emailing #{rsvp.email_address_with_name}..."
        InvitesMailer.waitlisted(rsvp).deliver_now
        rsvp.waitlist!
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

    client = Twilio::REST::Client.new HC_CONFIG.twilio_account_sid, HC_CONFIG.twilio_auth_token

    rsvps = RSVP.where(show: show, response: "yes", confirmed: "yes")
    rsvps.each do |rsvp|
      puts "Emailing #{rsvp.email_address_with_name}..."
      InvitesMailer.remind(rsvp).deliver_now

      next if rsvp.phone_number.blank?

      puts "Texting #{rsvp.phone_number}..."
      client.api.account.messages.create(
        from: HC_CONFIG.twilio_sms_sender,
        to: rsvp.phone_number_twilio,
        body: rsvp.sms_reminder
      )
    end
    print_confirmation(rsvps.size)
  end
end

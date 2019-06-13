namespace :next_show do
  desc 'Send invites for next show'
  task invite: :environment do
    show = Show.next
    if show.nil?
      puts 'No upcoming shows found'
      exit
    end

    people = Person.includes(:venue_groups)
                   .where(venue_groups: { id: 2 }, status: 'active')
                   .where('email NOT IN (SELECT email FROM rsvps WHERE show_id = ?)', show.id)
                   .order(:last_name, :first_name)

    people.each do |p|
      begin
        puts "Emailing #{p.email_address_with_name}..."
        Invites.invite(p, show).deliver_now
      rescue Net::SMTPServerBusy => e
        logger.warn "Failed to email #{p.email_address_with_name} [#{e.message}]"
      end
    end
    puts "Sent #{people.size} emails."
  end

  desc 'Send invites for next show to one person'
  task :invite_one, [:email] => [:environment] do |_, args|
    email = args[:email]
    unless email
      puts 'Please enter an email address'
      exit
    end

    person = Person.where(email: email).first
    if person.nil?
      puts "Could not find anyone with the email #{email}"
      exit
    end

    show = Show.next
    if show.nil?
      puts 'No upcoming shows found'
      exit
    end

    puts "Emailing #{person.email_address_with_name}..."
    Invites.invite(person, show).deliver_now
  end

  desc 'Send invites for next show to people who have not opened the invitation'
  task invite_unopened: :environment do
    show = Show.next
    if show.nil?
      puts 'No upcoming shows found'
      exit
    end

    people = Person.includes(:venue_groups)
                   .where(venue_groups: { id: 2 }, status: 'active')
                   .where('email NOT IN (SELECT email FROM rsvps WHERE show_id = ?)', show.id)
                   .where('email NOT IN (SELECT email FROM opens WHERE tag LIKE ?)', "#{show.slug}:invite%")
                   .order(:last_name, :first_name)

    people.each do |p|
      begin
        puts "Emailing #{p.email_address_with_name}..."
        Invites.invite(p, show).deliver_now
      rescue Net::SMTPServerBusy => e
        logger.warn "Failed to email #{p.email_address_with_name} [#{e.message}]"
      end
    end
    puts "Sent #{people.size} emails."
  end

  desc 'Count invites for next show'
  task invite_count: :environment do
    show = Show.next
    if show.nil?
      puts 'No upcoming shows found'
      exit
    end

    people = Person.includes(:venue_groups)
                   .where(venue_groups: { id: 2 }, status: 'active')
                   .where('email NOT IN (SELECT email FROM rsvps WHERE show_id = ?)', show.id)

    puts "Can email #{people.size} people."
  end

  desc 'Show attendees for next show'
  task attendees: :environment do
    show = Show.next
    if show.nil?
      puts 'No upcoming shows found'
      exit
    end

    seats = 0
    reservations = 0
    RSVP.where(show: show, response: 'yes').order(:id).each do |rsvp|
      puts "#{rsvp.created_at.to_date} #{rsvp.seats} #{rsvp.full_name}"
      seats += rsvp.seats
      reservations += 1
    end
    puts "Total: #{seats} seats / #{reservations} reservations"
  end

  desc 'Show RSVPs for next show'
  task rsvps: :environment do
    show = Show.next
    if show.nil?
      puts 'No upcoming shows found'
      exit
    end

    seats = 0
    reservations = 0
    confirmed = 0
    confirmed_seats = 0
    waitlisted = 0
    waitlisted_seats = 0
    RSVP.where(show: show).order(:id).each do |rsvp|
      if rsvp.confirmed?
        is_confirmed = '✔'
      elsif rsvp.waitlisted?
        is_confirmed = 'w'
      elsif rsvp.yes?
        is_confirmed = '✖'
      else
        is_confirmed = ' '
      end
      puts "#{rsvp.created_at.to_date} #{rsvp.response.rjust(3)}#{is_confirmed} #{rsvp.seats} #{rsvp.email}"
      seats += rsvp.seats
      reservations += 1 if rsvp.yes?
      if rsvp.confirmed?
        confirmed += 1
        confirmed_seats += rsvp.seats
      end
      if rsvp.waitlisted?
        waitlisted += 1
        waitlisted_seats += rsvp.seats
      end
    end
    puts "Total: #{seats} seats (#{confirmed_seats} confirmed #{waitlisted_seats} waitlisted) / #{reservations} reservations (#{confirmed} confirmed #{waitlisted} waitlisted)"
  end

  desc 'Show Email opens for next show'
  task opens: :environment do
    show = Show.next
    if show.nil?
      puts 'No upcoming shows found'
      exit
    end

    opens = Open.where('tag LIKE ?', "#{show.slug}%").group(:email).order(:created_at)
    opens.each do |open|
      puts "#{open.created_at.to_date} #{open.tag[show.slug.length + 1..-1]} #{open.email}"
    end
    puts "Opens: #{opens.size}"
  end

  desc 'Confirm RSVPs for next show'
  task confirm: :environment do
    show = Show.next
    if show.nil?
      puts 'No upcoming shows found'
      exit
    end

    if show.confirmed?
      rsvps = RSVP.where(show: show, response: 'yes').where("(confirmed != 'yes' OR confirmed IS NULL)")
      rsvps.each do |rsvp|
        puts "Emailing #{rsvp.email_address_with_name}..."
        Invites.confirm(rsvp).deliver_now
        rsvp.confirm!
      end
    elsif show.waitlisted?
      rsvps = RSVP.where(show: show, response: 'yes').where("( (confirmed != 'yes' AND confirmed != 'waitlisted') OR confirmed IS NULL)")
      rsvps.each do |rsvp|
        puts "Emailing #{rsvp.email_address_with_name}..."
        Invites.waitlisted(rsvp).deliver_now
        rsvp.waitlist!
      end
    end
    puts "Sent #{rsvps.size} emails."
  end

  desc 'Remind RSVPs for next show'
  task remind: :environment do
    show = Show.next
    if show.nil?
      puts 'No upcoming shows found'
      exit
    end

    client = Twilio::REST::Client.new HC_CONFIG.twilio_account_sid, HC_CONFIG.twilio_auth_token

    rsvps = RSVP.where(show: show, response: 'yes', confirmed: 'yes')
    rsvps.each do |rsvp|
      puts "Emailing #{rsvp.email_address_with_name}..."
      Invites.remind(rsvp).deliver_now

      next unless rsvp.phone_number.present?

      puts "Texting #{rsvp.phone_number}..."
      client.api.account.messages.create(
        from: HC_CONFIG.twilio_sms_sender,
        to: rsvp.phone_number_twilio,
        body: rsvp.sms_reminder
      )
    end
    puts "Sent #{rsvps.size} emails."
  end
end

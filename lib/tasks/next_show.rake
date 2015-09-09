namespace :next_show do
  desc 'Send invites for next show'
  task invite: :environment do
    show = Show.next
    people = Person.includes(:venue_groups).where(venue_groups: { id: 2 }, status: 'active').where('email NOT IN (SELECT email FROM rsvps WHERE show_id = ?)', show.id).order(:last_name, :first_name)

    people.each do |p|
      puts "Emailing #{p.email_address_with_name}..."
      Invites.invite(p, show).deliver_now
    end
    puts "Sent #{people.size} emails."
  end

  desc 'Count invites for next show'
  task invite_count: :environment do
    show = Show.next
    people = Person.includes(:venue_groups).where(venue_groups: { id: 2 }, status: 'active').where('email NOT IN (SELECT email FROM rsvps WHERE show_id = ?)', show.id)

    puts "Can email #{people.size} people."
  end

  desc 'Show RSVPs for next show'
  task rsvps: :environment do
    seats = 0
    reservations = 0
    RSVP.where(show: Show.next).order(:id).each do |rsvp|
      puts "#{rsvp.created_at.to_date} #{rsvp.response.rjust(3)} #{rsvp.seats} #{rsvp.email}"
      seats += rsvp.seats
      reservations += 1 if rsvp.yes?
    end
    puts "Total: #{seats} seats / #{reservations} reservations"
  end

  desc 'Show Email opens for next show'
  task opens: :environment do
    show = Show.next
    opens = Open.where('tag LIKE ?', "#{show.slug}%").group(:email).order(:created_at)
    opens.each do |open|
      puts "#{open.created_at.to_date} #{open.tag[show.slug.length + 1..-1]} #{open.email}"
    end
    puts "Opens: #{opens.size}"
  end

  desc 'Confirm RSVPs for next show'
  task confirm: :environment do
    show = Show.next
    rsvps = RSVP.where(show: show, response: 'yes').where("(confirmed != 'yes' OR confirmed IS NULL)")
    rsvps.each do |rsvp|
      puts "Emailing #{rsvp.email_address_with_name}..."
      Invites.confirm(rsvp).deliver_now
      rsvp.confirm!
    end
    puts "Sent #{rsvps.size} emails."
  end

  desc 'Remind RSVPs for next show'
  task remind: :environment do
    show = Show.next
    rsvps = RSVP.where(show: show, response: 'yes', confirmed: 'yes')
    rsvps.each do |rsvp|
      puts "Emailing #{rsvp.email_address_with_name}..."
      Invites.remind(rsvp).deliver_now
    end
    puts "Sent #{rsvps.size} emails."
  end
end

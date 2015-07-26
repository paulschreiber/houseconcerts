
namespace :next_show do

  desc 'Send invites for next show'
  task invite: :environment do
    show = Show.upcoming.first
    people = Person.includes(:venue_groups).where(venue_groups: { id: 2 }, status: 'active').where('email NOT IN (SELECT email FROM rsvps WHERE show_id = ?)', show.id)

    people.each do |p|
      puts "Emailing #{p.email_address_with_name}..."
      Invites.invite(p, show).deliver_now
    end
    puts "Sent #{people.size} emails."
  end

  desc 'Show RSVPs for next show'
  task rsvps :environment do
    RSVP.where(show: Show.upcoming.first).each do |rsvp|
      puts "#{rsvp.created_at.to_date} #{rsvp.email} #{rsvp.response} #{rsvp.seats}"
    end
  end

  desc 'Confirm RSVPs for next show'
  task confirm :environment do
    RSVP.where(show: Show.upcoming.first, response: "Yes", confirmed: nil).each do |rsvp|
      puts "Emailing #{p.email_address_with_name}..."
      Invites.confirm(p, show).deliver_now
    end
  end

end

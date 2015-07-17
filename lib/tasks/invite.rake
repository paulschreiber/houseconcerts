
namespace :invite do
  desc 'Send invites for next_show'
  task next_show: :environment do
    show = Show.upcoming.first
    people = Person.includes(:venue_groups).where(venue_groups: { id: 2 }, status: 'active').where('email NOT IN (SELECT email FROM rsvps WHERE show_id = ?)', show.id)

    people.each do |p|
      puts "Emailing #{p.email_address_with_name}..."
      Invites.invite(p, show).deliver_now
    end
    puts "Sent #{people.size} emails."
  end
end

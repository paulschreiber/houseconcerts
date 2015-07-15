
namespace :invite do
	desc "Send invites for next_show"
	task :next_show => :environment do
		people = Person.includes(:venue_groups).where(venue_groups: {id: 2}, status: "active")
		show = Show.upcoming.first

		people.each do |p|
			puts "Emailing #{p.email_address_with_name}..."
			Invites.invite(p, show).deliver_now
		end
	end
end
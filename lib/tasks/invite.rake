
namespace :invite do

  desc "Send invites for next_show"
  task :next_show => :environment do
    people = Person.includes(:venue_groups).where(venue_groups: {id: 2})
    show = Show.upcoming.first

  	people.each do |p|
      Invites.invite(p, show).deliver_now
    end
  end
end
namespace :people do
  desc "List people who RSVPd for the most recent show, but aren't on the list"
  task list_nonsubscribers: :environment do
    find_nonsubscribers.each do |rsvp|
      puts rsvp.email_address_with_name
    end
  end

  desc "Add people who RSVPd for the most recent show, and aren't on the list, to the list"
  task add_nonsubscribers: :environment do
    rsvps = find_nonsubscribers
    rsvps.each(&:create_person)
    puts "Added #{rsvps.collect(&:email).to_sentence}" unless rsvps.empty?
  end

  def find_nonsubscribers
    show = Show.past.last
    rsvps = RSVP.where(show: show).where('email NOT IN (SELECT email FROM people)')
    puts "Found #{rsvps.size} who RSVPd for #{show.name} and are not subscribed"
    rsvps
  end
end

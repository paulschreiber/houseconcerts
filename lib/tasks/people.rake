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
    show = Show.occurred.last
    rsvps = RSVP.where(show: show).where('email NOT IN (SELECT email FROM people)')
    puts "Found #{rsvps.size} who RSVPd for #{show.name} and are not subscribed"
    rsvps
  end

  desc 'List people who unsubscribed'
  task list_unsubscribers: :environment do
    people = Person.where(status: :removed).order(:removed_at).last(30)
    people.each do |p|
      puts "#{p.removed_at.to_date} #{p.email_address_with_name}"
    end
  end
end

def find_nonsubscribers
  show = Show.occurred.last
  rsvps = RSVP.where(show: show, response: "yes").where("email NOT IN (SELECT email FROM people)")
  puts "Found #{rsvps.size} who RSVPd for #{show.name} and are not subscribed"
  rsvps
end

namespace :people do
  desc "List people who RSVPd for the most recent show, but aren't on the list"
  task list_nonsubscribers: :environment do
    find_nonsubscribers.each do |rsvp|
      puts rsvp.email_address_with_name
    end
  end

  desc "Add phone numbers from RSVPs table to people in the people table"
  task add_phone_numbers: :environment do
    people = Person.where(phone_number: nil).where(email: RSVP.where.not(phone_number: nil).select(:email))
    people.each do |person|
      rsvp = RSVP.where(email: person.email).where.not(phone_number: nil).order(id: :desc).first
      next unless rsvp && rsvp.phone_number.present?

      puts "Adding phone number #{rsvp.phone_number} to person #{person.email}"
      person.update(phone_number: rsvp.phone_number)
    end
  end

  desc "Add people who RSVPd for the most recent show, and aren't on the list, to the list"
  task add_nonsubscribers: :environment do
    rsvps = find_nonsubscribers
    rsvps.each(&:create_person)
    puts "Added #{rsvps.collect(&:email).to_sentence}" unless rsvps.empty?
  end

  desc "List people who unsubscribed"
  task list_unsubscribers: :environment do
    people = Person.where(status: :removed).order(:removed_at).last(30)
    people.each do |p|
      puts "#{p.removed_at.to_time} #{p.email_address_with_name}"
    end
  end

  desc "Import subscribers"
  task :import_subscribers, [ :filename ] => [ :environment ] do |_, args|
    import_target = args[:filename]

    unless import_target
      puts "Please enter an a filename"
      exit
    end

    unless File.exist?(import_target)
      puts "#{import_target} does not exist"
      exit
    end

    begin
      data = File.read(import_target)
      if data.empty?
        puts "#{import_target} is blank"
        exit
      end
    rescue Errno::EACCES => e
      puts "#{import_target} cannot be read (#{e.message})"
      exit
    end

    imported = []
    data.split("\n").each do |line|
      matches = line.match(/(.*) (.*) <([^>]+)>/)
      if matches.nil? || matches.size != 4
        puts "Skipping: [#{line}]"
      else
        begin
          Person.create(first_name: matches[1], last_name: matches[2], email: matches[3])
          imported << matches[3]
        rescue ActiveRecord::RecordNotUnique
          puts "Duplicate: [#{line}]"
        end
      end
    end

    puts "Import #{imported.to_sentence}" unless imported.empty?
  end
end

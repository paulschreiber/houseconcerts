def find_nonsubscribers
  show = Show.occurred.last
  rsvps = RSVP.nonsubscribers(show)
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
    AddPhoneNumbers.call.each do |person|
      puts "Added phone number #{person.phone_number} to person #{person.email}"
    end
  end

  desc "Add people who RSVPd for the most recent show, and aren't on the list, to the list"
  task add_nonsubscribers: :environment do
    show = Show.occurred.last
    result = AddNonsubscribers.call(show)
    puts "Found #{result.added.size + result.skipped.size + result.failed.size} who RSVPd for #{show.name} and are not subscribed"
    puts "Added #{result.added.collect(&:email).to_sentence}" unless result.added.empty?
    puts "Skipped #{result.skipped.collect(&:email).to_sentence} (unsubscribed, bouncing or moved)" unless result.skipped.empty?
    result.failed.each { |rsvp, errors| puts "Couldn't add #{rsvp.email}: #{errors}" }
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
      exit 1
    end

    unless File.file?(import_target)
      puts "#{import_target} does not exist, or isn't a file"
      exit 1
    end

    begin
      data = File.binread(import_target)
      if data.empty?
        puts "#{import_target} is blank"
        exit 1
      end
    rescue Errno::EACCES => e
      puts "#{import_target} cannot be read (#{e.message})"
      exit 1
    end

    begin
      result = ImportPeople.call(data, filename: import_target)
    rescue ImportPeople::Error => e
      puts e.message
      exit 1
    end

    result.invalid.each { |line| puts "Skipping: [#{line.text}] (#{line.reason})" }
    result.skipped.each { |line| puts "Duplicate: [#{line.text}] (#{line.reason})" }
    puts "Imported #{result.added.collect(&:email).to_sentence}" unless result.added.empty?
  end
end

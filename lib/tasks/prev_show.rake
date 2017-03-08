namespace :prev_show do
  desc 'Show attendees for previous show'
  task attendees: :environment do
    seats = 0
    reservations = 0
    RSVP.where(show: Show.previous, response: 'yes').order(:id).each do |rsvp|
      puts "#{rsvp.created_at.to_date} #{rsvp.seats} #{rsvp.email_address_with_name}"
      seats += rsvp.seats
      reservations += 1
    end
    puts "Total: #{seats} seats / #{reservations} reservations"
  end
end

namespace :prev_show do
  desc "Show attendees for previous show"
  task attendees: :environment do
    seats_reserved = 0
    reservations = 0
    RSVP.where(show: Show.previous, response: "yes").order(:id).each do |rsvp|
      puts "#{rsvp.created_at.to_date} #{rsvp.seats_reserved} #{rsvp.email_address_with_name}"
      seats_reserved += rsvp.seats_reserved
      reservations += 1
    end
    puts "Total: #{seats_reserved} seats / #{reservations} reservations"
  end
end

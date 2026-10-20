namespace :prev_show do
  desc "Show attendees for previous show"
  task attendees: :environment do
    rsvps = RSVP.previous_show_attendees.order(:id).to_a
    rsvps.each do |rsvp|
      puts "#{rsvp.created_at.to_date} #{rsvp.seats_reserved} #{rsvp.email_address_with_name}"
    end
    puts "Total: #{rsvps.sum(&:seats_reserved)} seats / #{rsvps.size} reservations"
  end
end

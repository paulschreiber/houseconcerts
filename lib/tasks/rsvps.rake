
namespace :rsvps do
  desc 'Show RSVPs for next show'
  task next_show: :environment do
    RSVP.where(show: Show.upcoming.first).each do |rsvp|
      puts "#{rsvp.created_at.to_date} #{rsvp.email} #{rsvp.response} #{rsvp.seats}"
    end
  end
end

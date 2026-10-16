# Helpers for the tasks below.
module NextShowTasks
  # The rsvps task's mark for each yes RSVP's confirmation status.
  STATUS_MARKS = { "confirmed" => "✔", "waitlisted" => "w", "unconfirmed" => "✖" }.freeze

  module_function

  def next_show_or_exit
    show = Show.next
    return show if show

    puts "No upcoming shows found"
    exit
  end

  def run_batch(show, kind, noun)
    # Recipients are computed and enqueued in the background (BatchRunFanOutJob),
    # so the count isn't known yet here -- check the show's madmin page for progress.
    StartBatchRun.call(show: show, kind: kind)
    puts "Started sending #{noun.pluralize} for #{show.name}."
  rescue StartBatchRun::AlreadyInProgress
    puts "A #{kind} batch is already in progress for #{show.name}; not starting another."
  rescue StartBatchRun::NotReady, StartBatchRun::EnqueueFailed => e
    puts e.message
  end

  # The RSVPs the confirm task emails for the show's availability, and the
  # service that emails each one. A sold-out show has none.
  def confirm_targets(show)
    return [ show.rsvps.awaiting_confirmation.to_a, ConfirmRSVP ] if show.can_confirm_rsvps?
    return [ show.rsvps.yes.confirmed_unconfirmed.to_a, WaitlistRSVP ] if show.can_waitlist_rsvps?

    [ [], nil ]
  end
end

namespace :next_show do
  desc "Send invites for next show"
  task invite: :environment do
    show = NextShowTasks.next_show_or_exit

    NextShowTasks.run_batch(show, "invite", "invite")
  end

  desc "Send invites for next show to one person"
  task :invite_one, [ :email ] => [ :environment ] do |_, args|
    email = args[:email]
    unless email
      puts "Please enter an email address"
      exit
    end

    person = Person.find_by(email: email)
    if person.nil?
      puts "Could not find anyone with the email #{email}"
      exit
    end

    show = NextShowTasks.next_show_or_exit

    unless person.can_invite?
      puts "Email #{email} can’t be invited"
      exit
    end

    unless show.invite_message
      puts "Write the invite for #{show.name} first"
      exit
    end

    puts "Emailing #{person.email_address_with_name}..."
    if InvitePerson.call(person, show, deliver_now: true)
      puts "Sent."
    else
      puts "Failed to send."
    end
  end

  desc "Send invites for next show to people who have not opened the invitation"
  task invite_unopened: :environment do
    show = NextShowTasks.next_show_or_exit

    NextShowTasks.run_batch(show, "invite_unopened", "invite")
  end

  desc "Count invites for next show"
  task invite_count: :environment do
    show = NextShowTasks.next_show_or_exit

    puts "Can email #{Person.invitable_for(show).size} people."
  end

  desc "Show attendees for next show"
  task attendees: :environment do
    show = NextShowTasks.next_show_or_exit

    rsvps = show.attendees.order(:id).to_a
    people_emails = Person.where(email: rsvps.map(&:email)).pluck(:email).to_set
    rsvps.each do |rsvp|
      puts "#{rsvp.created_at.to_date} #{rsvp.seats_reserved} #{people_emails.include?(rsvp.email) ? ' ' : '✖'} #{rsvp.phone_number.to_s.ljust(14)} #{rsvp.full_name}"
    end
    puts "Total: #{rsvps.sum(&:seats_reserved)} seats / #{rsvps.size} reservations"
  end

  desc "Show RSVPs for next show"
  task rsvps: :environment do
    show = NextShowTasks.next_show_or_exit

    rsvps = show.rsvps.order(:id).to_a
    rsvps.each do |rsvp|
      status = rsvp.yes? ? NextShowTasks::STATUS_MARKS.fetch(rsvp.confirmed) : " "
      puts "#{rsvp.created_at.to_date} #{rsvp.response.rjust(3)}#{status} #{rsvp.seats_reserved} #{rsvp.email}"
    end

    yes = rsvps.select(&:yes?)
    confirmed = yes.select(&:confirmed?)
    waitlisted = yes.select(&:waitlisted?)
    puts "Total: #{yes.sum(&:seats_reserved)} seats (#{confirmed.sum(&:seats_reserved)} confirmed #{waitlisted.sum(&:seats_reserved)} waitlisted) / " \
         "#{yes.size} reservations (#{confirmed.size} confirmed #{waitlisted.size} waitlisted) / #{rsvps.size - yes.size} declines"
  end

  desc "Show Unconfirmed RSVPs for next show"
  task unconfirmed: :environment do
    show = NextShowTasks.next_show_or_exit

    rsvps = show.rsvps.awaiting_confirmation.order(:id).to_a
    rsvps.each do |rsvp|
      puts "#{rsvp.created_at.to_date} #{rsvp.response.rjust(3)}#{rsvp.waitlisted? ? 'w' : ' '} #{rsvp.seats_reserved} #{rsvp.email}"
    end

    waitlisted, unconfirmed = rsvps.partition(&:waitlisted?)
    puts "Total: #{rsvps.sum(&:seats_reserved)} seats (#{unconfirmed.sum(&:seats_reserved)} unconfirmed #{waitlisted.sum(&:seats_reserved)} waitlisted) / " \
         "#{rsvps.size} reservations (#{unconfirmed.size} unconfirmed #{waitlisted.size} waitlisted)"
  end

  desc "Show Email opens for next show"
  task opens: :environment do
    show = NextShowTasks.next_show_or_exit

    opens = Open.for_show(show).order(:created_at).to_a
    first_opens = opens.uniq(&:email)
    first_opens.each do |open|
      puts "#{open.created_at.to_date} #{open.tag.delete_prefix("#{show.slug}:")} #{open.email}"
    end
    puts "Opens: #{first_opens.size} emails #{opens.size} opens"
  end

  desc "Confirm RSVPs for next show"
  task confirm: :environment do
    show = NextShowTasks.next_show_or_exit

    unless show.confirmed?
      puts "Next show is not confirmed"
      exit
    end

    rsvps, service = NextShowTasks.confirm_targets(show)

    sent = rsvps.count do |rsvp|
      puts "Emailing #{rsvp.email_address_with_name}..."
      service.call(rsvp)
    end
    puts "Sent #{sent} #{'email'.pluralize(sent)}, #{rsvps.size - sent} failed."
  end

  desc "Remind RSVPs for next show"
  task remind: :environment do
    show = NextShowTasks.next_show_or_exit

    NextShowTasks.run_batch(show, "remind", "reminder")
  end
end

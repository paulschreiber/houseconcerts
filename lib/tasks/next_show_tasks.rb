# Helpers for the next_show tasks, required once by lib/tasks/next_show.rake so
# that loading the tasks again (as the tests do after test:prepare) doesn't
# redefine STATUS_MARKS. Like the tasks, they print to the terminal and exit.
# rubocop:disable-next Rails/Output, Rails/Exit
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

  # Yields each RSVP the confirm task emails, oldest first, with the service
  # that emails it: ConfirmRSVP for an RSVP that can be confirmed, WaitlistRSVP
  # for an unconfirmed one that can't. Each RSVP is checked when it's reached,
  # after the service has run for the ones before it, since waitlisting one
  # RSVP leaves room for the next.
  def each_confirm_target(show)
    show.rsvps.awaiting_confirmation.order(:id).each do |rsvp|
      if rsvp.can_confirm?
        yield rsvp, ConfirmRSVP
      elsif rsvp.can_waitlist?
        yield rsvp, WaitlistRSVP
      end
    end
  end
end

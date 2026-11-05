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

  # The RSVPs the confirm task emails for the show's availability, and the
  # service that emails each one. A sold-out show has none.
  def confirm_targets(show)
    return [ show.rsvps.awaiting_confirmation.to_a, ConfirmRSVP ] if show.can_confirm_rsvps?
    return [ show.rsvps.yes.confirmed_unconfirmed.to_a, WaitlistRSVP ] if show.can_waitlist_rsvps?

    [ [], nil ]
  end
end

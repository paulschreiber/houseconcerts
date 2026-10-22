class ShowResource < Madmin::Resource
  # Starting a batch emails everyone eligible, so it asks first -- and says so
  # when a batch of this kind has already gone out for this show, since
  # "Send Invites" again re-sends to everyone who still hasn't RSVP'd.
  def self.start_confirmation(show, kind)
    description = BatchRun.kind_description(kind)
    previous = show.batch_runs.where(kind: kind).delivered.maximum(:completed_at)
    return "Send #{description} for #{show.name}?" unless previous

    "#{BatchRun.kind_label(kind)} already went out for #{show.name} on #{previous.to_date.to_fs(:long)}. Send #{description} again?"
  end

  # Attributes
  attribute :id
  attribute :start, field: ShortDateTimeField, format: "%Y-%m-%d", index_label: "Date", index: true
  attribute :end
  attribute :name, field: LinkedStringField
  attribute :slug, field: ReadonlyStringField, form: false, new: true, edit: true
  attribute :blurb, field: MultilineTextField
  attribute :price
  attribute :created_at
  attribute :updated_at
  attribute :availability, field: RadioEnumField
  attribute :status, field: RadioEnumField

  # Associations
  attribute :artists
  attribute :rsvps, form: false, show: false
  attribute :venue

  # Add scopes to easily filter records
  scope :upcoming
  scope :past
  scope :available
  scope :waitlisted
  scope :sold_out
  scope :confirmed
  scope :unconfirmed
  scope :cancelled

  # Add actions to the resource's show page
  # Pass collection: true to also render it in each row on the index page
  member_action do |record|
    attendance = if record.occurred?
      link_to("Attendance", attendance_madmin_show_path(record), class: "btn btn-secondary")
    else
      tag.button("Attendance", type: "button", class: "btn btn-secondary", **ShowResource.disabled_options(ShowResource::AFTER_SHOW))
    end
    link_to("Print Attendance", print_attendance_madmin_show_path(record), class: "btn btn-secondary", target: "_blank", rel: "noopener") +
      attendance
  end

  # The invite, on its own row: edit its current revision, or start one if
  # there's none yet or the current one has been sent.
  member_action do |record|
    current = record.invite_message
    buttons = if current.nil?
      render "madmin/invite_messages/new_button", show: record, label: "Write Invite"
    else
      edit = if current.locked?
        render "madmin/invite_messages/new_button", show: record, label: "New Invite Revision"
      else
        render "madmin/invite_messages/edit_button", invite_message: current, locked: false, label: "Edit Invite"
      end
      edit + link_to("Invite History", madmin_show_invite_messages_path(record), class: "btn btn-secondary")
    end
    tag.div(buttons, class: "actions-row")
  end

  # The spacer pushes Edit and Delete, which Madmin adds next, to the right
  # of this line, as on other record pages.
  member_action do |record|
    options = ShowResource.disabled_options(record.occurred? ? nil : ShowResource::AFTER_SHOW)
    button_to("Add Nonsubscribers", add_nonsubscribers_madmin_show_path(record), class: "btn btn-secondary", **options) +
      button_to("Add Phone Numbers", add_phone_numbers_madmin_show_path(record), class: "btn btn-secondary", **options) +
      tag.span(class: "actions-spacer")
  end

  # On the index, beside View and Edit: print the list for upcoming shows,
  # record attendance for past ones. (The show page has both, above.)
  member_action(collection: true) do |record|
    case params[:scope]
    when "upcoming"
      link_to "Print Attendance", print_attendance_madmin_show_path(record), class: "btn btn-secondary", target: "_blank", rel: "noopener"
    when "past"
      link_to "Record Attendance", attendance_madmin_show_path(record), class: "btn btn-secondary"
    end
  end

  member_action do |record|
    # Only the next show can start a batch; any show with batches shows their
    # progress, and their failures until it has happened.
    next_show = record.next_show?
    send_buttons = if next_show
      tag.div(class: "actions-row") do
        safe_join(BatchRun::KINDS.map do |kind, details|
          # Turbo disables the button while the request is in flight.
          button_to(details[:button], start_batch_run_madmin_show_path(record, kind:),
                    method: :patch, class: "btn btn-secondary",
                    data: { turbo_confirm: ShowResource.start_confirmation(record, kind) },
                    **ShowResource.invite_gate_options(record, kind))
        end)
      end
    end

    # Always rendered for the next show, even before its first batch, so an
    # open page picks up a batch started elsewhere (another tab, the rake task).
    progress = render(partial: "madmin/shows/batch_progress", locals: { show: record }) if next_show || record.batch_runs.exists?

    safe_join([ send_buttons, progress ].compact)
  end

  # Recording attendance and adding RSVPs to the mailing list wait until the
  # show has started, when its RSVPs are final.
  AFTER_SHOW = "Available once the show starts".freeze

  # A button's options: disabled, with the reason as its tooltip, if there's
  # a reason.
  def self.disabled_options(reason)
    reason ? { disabled: true, title: reason } : {}
  end

  # Send to Unopened / Send Reminders only make sense after an initial
  # invite has gone out, and invites need one written.
  def self.invite_gate_options(show, kind)
    disabled_options(BatchRun.not_ready_reason(show, kind))
  end

  # Customize the display name of records in the admin area.
  def self.display_name(record)
    record.dated_name
  end

  # Customize the default sort column and direction.
  def self.default_sort_column
    "start"
  end

  # Upcoming shows are soonest first, everything else most recent first.
  def self.default_sort_direction
    Current.admin_scope == "upcoming" ? "asc" : "desc"
  end

  menu position: 20
end

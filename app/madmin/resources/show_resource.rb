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
    link_to("Attendance", attendance_madmin_show_path(record), class: "btn btn-secondary") +
      link_to("Print Attendance", print_attendance_madmin_show_path(record), class: "btn btn-secondary", target: "_blank", rel: "noopener")
  end

  member_action do |record|
    button_to("Add Nonsubscribers", add_nonsubscribers_madmin_show_path(record), class: "btn btn-secondary") +
      button_to("Add Phone Numbers", add_phone_numbers_madmin_show_path(record), class: "btn btn-secondary")
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
    # Only the next show can have a new batch started, but batch history
    # stays visible for every other show that has ever had one, so a past
    # show's failed sends are still visible from its own page. Retry
    # buttons appear only until the show has happened (see
    # _batch_run_progress), since sends for a past show are useless.
    send_buttons = if record.next_show?
      safe_join(BatchRun::KINDS.map do |kind, details|
        # Turbo disables the button while the request is in flight.
        button_to(details[:button], start_batch_run_madmin_show_path(record, kind:),
                  method: :patch, class: "btn btn-secondary",
                  data: { turbo_confirm: ShowResource.start_confirmation(record, kind) },
                  **ShowResource.invite_gate_options(record, kind))
      end)
    end

    # Also rendered for the next show even with zero batch runs yet
    # (not just record.batch_runs.exists?): only the next show can ever
    # have a new one started (see above), so it's the only show whose
    # batch_runs.exists? can ever flip from false to true. Without the
    # subscription/DOM targets this partial renders already being on the
    # page beforehand, an admin with this tab open when a batch is
    # triggered elsewhere -- another tab, the rake task, a cron job --
    # would never see it appear.
    progress = render(partial: "madmin/shows/batch_progress", locals: { show: record }) if record.next_show? || record.batch_runs.exists?

    safe_join([ send_buttons, progress ].compact)
  end

  # Send to Unopened / Send Reminders only make sense after an initial
  # invite has gone out.
  def self.invite_gate_options(show, kind)
    return {} if !BatchRun.requires_invites_sent?(kind) || show.invites_sent?

    { disabled: true, title: "Send invites first" }
  end

  # Customize the display name of records in the admin area.
  def self.display_name(record) = "#{record.name} — #{record.start.strftime('%Y-%m-%d')}"

  # Customize the default sort column and direction.
  def self.default_sort_column = "start"

  # Upcoming shows are soonest first, everything else most recent first.
  def self.default_sort_direction = Current.admin_scope == "upcoming" ? "asc" : "desc"

  menu position: 20
end

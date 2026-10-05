class ShowResource < Madmin::Resource
  # Disables a batch-action button immediately on submit, so a rapid
  # double-click can't fire the same start/retry action twice before the
  # first request's redirect replaces the page. A fresh hash every call
  # (not a shared frozen constant): button_to mutates whatever's passed
  # as :form in place (setting :class, :method, :action on it).
  #
  # Disabled on turbo:submit-start rather than submit: Turbo shows a button's
  # data-turbo-confirm dialog after the submit event, so disabling on submit
  # would leave the button stuck disabled if the admin dismissed the dialog.
  # The controller only disables buttons marked as its submit target -- see
  # submit_button_data.
  def self.disable_on_submit
    { data: { controller: "disable-on-submit", action: "turbo:submit-start->disable-on-submit#disable" } }
  end

  # The button's half of disable_on_submit, plus any other data attributes
  # (e.g. turbo_confirm) for that button.
  def self.submit_button_data(**data)
    data.merge(disable_on_submit_target: "submit")
  end

  # Starting a batch emails everyone eligible, so it asks first -- and says so
  # when a batch of this kind has already gone out for this show, since
  # "Send Invites" again re-sends to everyone who still hasn't RSVP'd. Only
  # runs that sent something count: a run cancelled before sending, or one
  # where every send failed, is also "completed".
  def self.start_confirmation(show, kind, description)
    previous = show.batch_runs.where(kind: kind, sent_count: 1..).completed.maximum(:completed_at)
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
      gate = ShowResource.invite_gate_options(record)
      # A lambda, so every button gets fresh hashes (button_to mutates :form).
      options = lambda do |kind, description|
        { method: :patch, class: "btn btn-secondary", form: ShowResource.disable_on_submit,
          data: ShowResource.submit_button_data(turbo_confirm: ShowResource.start_confirmation(record, kind, description)) }
      end

      safe_join([
                  button_to("Send Invites", send_invites_madmin_show_path(record), **options.call("invite", "invites")),
                  button_to("Send to Unopened", send_invites_unopened_madmin_show_path(record),
                            **options.call("invite_unopened", "invites to unopened recipients"), **gate),
                  button_to("Send Reminders", send_reminders_madmin_show_path(record), **options.call("remind", "reminders"), **gate)
                ])
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
  def self.invite_gate_options(show)
    return {} if show.invites_sent?

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

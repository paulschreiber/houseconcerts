class ShowResource < Madmin::Resource
  # Disables a batch-action button immediately on submit, so a rapid
  # double-click can't fire the same start/retry action twice before the
  # first request's redirect replaces the page. A fresh hash every call
  # (not a shared frozen constant): button_to mutates whatever's passed
  # as :form in place (setting :class, :method, :action on it).
  def self.disable_on_submit
    { data: { controller: "disable-on-submit", action: "submit->disable-on-submit#disable" } }
  end

  # Attributes
  attribute :id
  attribute :start
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
    # Only the next show can have a new batch started, but batch history
    # (and any retry buttons for still-failed items) stays visible for
    # every other show that has ever had one -- otherwise a past show's
    # failed sends would be invisible and unretryable from its own page.
    send_buttons = if record.next_show?
      gate = ShowResource.invite_gate_options(record)

      safe_join([
                  button_to("Send Invites", send_invites_madmin_show_path(record), method: :patch, class: "btn btn-secondary", form: ShowResource.disable_on_submit),
                  button_to("Send to Unopened", send_invites_unopened_madmin_show_path(record), method: :patch, class: "btn btn-secondary", form: ShowResource.disable_on_submit, **gate),
                  button_to("Send Reminders", send_reminders_madmin_show_path(record), method: :patch, class: "btn btn-secondary", form: ShowResource.disable_on_submit, **gate)
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

  # Add actions to the resource's index page
  # collection_action do
  #   link_to "Bulk Import", bulk_import_path, class: "btn btn-secondary"
  # end

  # Customize the display name of records in the admin area.
  def self.display_name(record) = "#{record.name} — #{record.start.strftime('%Y-%m-%d')}"

  # Customize the default sort column and direction.
  def self.default_sort_column = "start"

  def self.default_sort_direction
    Current.admin_scope == "upcoming" ? "asc" : "desc"
  end

  menu position: 20
end

class ShowResource < Madmin::Resource
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
    next unless record.next_show?

    gate = ShowResource.invite_gate_options(record)

    safe_join([
                button_to("Send Invites", send_invites_madmin_show_path(record), method: :patch, class: "btn btn-secondary"),
                button_to("Send to Unopened", send_invites_unopened_madmin_show_path(record), method: :patch, class: "btn btn-secondary", **gate),
                button_to("Send Reminders", send_reminders_madmin_show_path(record), method: :patch, class: "btn btn-secondary", **gate),
                render(partial: "madmin/shows/batch_progress", locals: { show: record })
              ])
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

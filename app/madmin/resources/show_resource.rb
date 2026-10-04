class ShowResource < Madmin::Resource
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

  # Add actions to the resource's index page
  # collection_action do
  #   link_to "Bulk Import", bulk_import_path, class: "btn btn-secondary"
  # end

  # Customize the display name of records in the admin area.
  def self.display_name(record) = "#{record.name} — #{record.start.strftime('%Y-%m-%d')}"

  # Customize the default sort column and direction.
  def self.default_sort_column = "start"

  # Upcoming shows are soonest first, everything else most recent first.
  def self.default_sort_direction = Current.admin_scope == "upcoming" ? "asc" : "desc"

  menu position: 20
end

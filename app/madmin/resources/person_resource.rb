class PersonResource < Madmin::Resource
  # Attributes
  attribute :id
  attribute :full_name, field: LinkedStringField, label: "Name", form: false, index: true
  attribute :uniqid, form: false, show: false, searchable: false
  attribute :first_name, searchable: true
  attribute :last_name, searchable: true
  attribute :email, searchable: true
  attribute :phone_number, searchable: false
  attribute :postcode, label: "Postal Code", searchable: false
  attribute :notes, field: MultilineTextField, searchable: false
  attribute :ip_address, field: ReadonlyStringField, form: false, new: true, edit: true, searchable: false
  attribute :removal_ip_address, field: ReadonlyStringField, form: false, new: true, edit: true, searchable: false
  attribute :removed_at, field: RemovedAtField, form: false, new: true, edit: true, index: true
  attribute :created_at, field: ShortDateTimeField, index: true
  attribute :updated_at
  attribute :status, field: RadioEnumField, index: true

  # Associations
  attribute :venue_groups

  # Add scopes to easily filter records
  scope :active
  scope :removed

  # Add actions to the resource's show page
  # Pass collection: true to also render it in each row on the index page
  member_action(collection: true) do |record|
    next unless @next_show

    buttons = []
    buttons << button_to("Invite", invite_madmin_person_path(record), method: :patch, class: "btn btn-secondary") if record.can_invite?
    buttons << button_to("RSVP No", rsvp_no_madmin_person_path(record), method: :patch, class: "btn btn-secondary") if record.can_rsvp_no?(@next_show)
    safe_join(buttons)
  end

  # Add actions to the resource's index page
  # collection_action do
  #   link_to "Bulk Import", bulk_import_path, class: "btn btn-secondary"
  # end

  # Customize the display name of records in the admin area.
  def self.display_name(record) = record.full_name

  # Customize the default sort column and direction.
  def self.default_sort_column = Arel.sql("last_name, first_name")

  def self.default_sort_direction = "asc"

  menu position: 30
end

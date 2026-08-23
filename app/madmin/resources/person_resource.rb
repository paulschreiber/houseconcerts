class PersonResource < Madmin::Resource
  # Attributes
  attribute :id
  attribute :full_name, field: LinkedStringField, label: "Name", form: false, index: true
  attribute :uniqid, form: false, show: false
  attribute :first_name
  attribute :last_name
  attribute :email
  attribute :phone_number
  attribute :postcode, label: "Postal Code"
  attribute :notes, field: MultilineTextField
  attribute :ip_address, field: ReadonlyStringField, form: false, new: true, edit: true
  attribute :removal_ip_address, field: ReadonlyStringField, form: false, new: true, edit: true
  attribute :removed_at, field: RemovedAtField, form: false, new: true, edit: true, index: true
  attribute :created_at
  attribute :updated_at
  attribute :status, field: RadioEnumField

  # Associations
  attribute :venue_groups

  # Add scopes to easily filter records
  scope :removed

  # Add actions to the resource's show page
  # Pass collection: true to also render it in each row on the index page
  # member_action do |record|
  #   link_to "Do Something", some_path
  # end

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

class VenueResource < Madmin::Resource
  # Attributes
  attribute :id
  attribute :name, field: LinkedStringField
  attribute :slug, field: ReadonlyStringField, form: false, new: true, edit: true
  attribute :address
  attribute :city
  attribute :province
  attribute :postcode, label: "Postal Code"
  attribute :country
  attribute :capacity
  attribute :created_at
  attribute :updated_at
  attribute :directions, field: MultilineTextField
  attribute :contact_info, field: MultilineTextField

  # Associations
  attribute :venue_groups
  attribute :shows, form: false, show: false

  # Customize the display name of records in the admin area.
  def self.display_name(record) = record.name

  # Customize the default sort column and direction.
  def self.default_sort_column = "name"

  def self.default_sort_direction = "asc"

  menu position: 50
end

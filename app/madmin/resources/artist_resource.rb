class ArtistResource < Madmin::Resource
  # Attributes
  attribute :id
  attribute :name, field: LinkedStringField
  attribute :slug, field: ReadonlyStringField, form: false, new: true, edit: true
  attribute :url, label: "URL"
  attribute :created_at
  attribute :updated_at

  # Associations
  attribute :shows, field: ReadonlyHasManyField, form: false, new: true, edit: true

  # Customize the display name of records in the admin area.
  def self.display_name(record) = record.name

  # Customize the default sort column and direction.
  def self.default_sort_column = "name"

  def self.default_sort_direction = "asc"

  menu position: 10
end

class VenueGroupResource < Madmin::Resource
  # Attributes
  attribute :id
  attribute :name, field: LinkedStringField
  attribute :created_at
  attribute :updated_at

  # Associations
  attribute :venues
  attribute :people, show: false, form: false

  # Customize the display name of records in the admin area.
  def self.display_name(record)
    record.name
  end

  # Customize the default sort column and direction.
  def self.default_sort_column
    "name"
  end

  def self.default_sort_direction
    "asc"
  end

  menu position: 60
end

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

  # Add scopes to easily filter records
  # scope :published

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
  def self.display_name(record) = record.name

  # Customize the default sort column and direction.
  # def self.default_sort_column = "created_at"
  #
  # def self.default_sort_direction = "desc"

  menu position: 50
end

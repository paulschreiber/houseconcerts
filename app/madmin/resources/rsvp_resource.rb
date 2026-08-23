class RSVPResource < Madmin::Resource
  # Attributes
  attribute :id
  attribute :full_name, field: LinkedStringField, label: "Name", form: false, index: true
  attribute :show_name, field: ComputedField, label: "Show Name", form: false, show: false, index: true,
                        compute: ->(record) { record.show&.name }
  attribute :show_date, field: ComputedField, label: "Show Date", form: false, show: false, index: true,
                        compute: ->(record) { record.show&.start&.strftime("%Y-%m-%d") }
  attribute :uniqid, form: false, show: false
  attribute :first_name
  attribute :last_name
  attribute :email
  attribute :phone_number
  attribute :postcode, label: "Postal Code"
  attribute :seats_reserved
  attribute :seats_used
  attribute :ip_address, field: ReadonlyStringField, form: false, new: true, edit: true
  attribute :confirmed_at, field: ReadonlyDateTimeField, form: false, new: true, edit: true
  attribute :created_at
  attribute :updated_at
  attribute :referrer, field: ReadonlyStringField, form: false, new: true, edit: true
  attribute :response, field: RadioEnumField
  attribute :confirmed, field: RadioEnumField

  # Associations
  attribute :show

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
  def self.display_name(record) = "#{record.full_name} — #{record.show&.name} #{record.show&.start&.strftime('%Y-%m-%d')}"

  # Customize the default sort column and direction.
  # def self.default_sort_column = "created_at"
  #
  # def self.default_sort_direction = "desc"

  menu position: 40
end

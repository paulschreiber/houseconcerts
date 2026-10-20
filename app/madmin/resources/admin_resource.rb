class AdminResource < Madmin::Resource
  # Attributes. Only the email is editable: new admins set their own password
  # from the email AdminsController#create sends.
  attribute :id, form: false
  attribute :email, field: LinkedStringField, searchable: true, index: true
  attribute :passkey_names, field: ComputedField, label: "Passkeys", form: false,
                            compute: ->(record) { record.passkeys.map(&:name).sort.to_sentence.presence || "None" }
  attribute :sign_in_count, label: "Sign-ins", form: false, index: true
  attribute :last_sign_in_at, field: ShortDateTimeField, label: "Last sign-in", form: false, index: true
  attribute :last_sign_in_ip, label: "Last sign-in IP", form: false
  attribute :current_sign_in_at, label: "Current sign-in", form: false
  attribute :current_sign_in_ip, label: "Current sign-in IP", form: false
  attribute :created_at, form: false
  attribute :updated_at, form: false

  # Customize the display name of records in the admin area.
  def self.display_name(record)
    record.email
  end

  # Customize the default sort column and direction.
  def self.default_sort_column
    "email"
  end

  def self.default_sort_direction
    "asc"
  end

  # Listed after Jobs in madmin/application/_navigation.
  menu false
end

class OpenResource < Madmin::Resource
  # Attributes
  attribute :id
  attribute :email, index: true
  attribute :tag, index: true
  attribute :ip_address, index: true
  attribute :open, index: true
  attribute :click, index: true
  attribute :created_at, field: ShortDateTimeField, index: true
  attribute :updated_at

  def self.readonly? = true

  # Madmin calls .pluralize on friendly_name in several of its own templates
  # (index title, sidebar label, breadcrumbs); a plain override would get
  # mangled into "Emails Openeds". Returning a string whose #pluralize is a
  # no-op keeps the fix local to this resource, without a global inflection.
  def self.friendly_name
    "Emails Opened".dup.tap { |s| def s.pluralize = self }
  end

  # Customize the default sort column and direction.
  def self.default_sort_column = "created_at"

  def self.default_sort_direction = "desc"

  menu position: 44
end

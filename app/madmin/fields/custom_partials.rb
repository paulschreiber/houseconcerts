# Lets a field render the views it names with its own partials (in
# app/views/madmin/fields/<field_type>/), and every other view with the
# partials of the field it extends. For example, `custom_partials :form`, or
# `custom_partials form: OtherField` to use OtherField's form partial.
module CustomPartials
  extend ActiveSupport::Concern

  VIEWS = %w[index show form].freeze

  included do
    # Which directory each view's partial comes from, e.g. for EmailField
    # { "index" => "string", "show" => "email_field", "form" => "string" }.
    # It starts with every view using the Madmin field type's partials;
    # custom_partials overrides views, and subclasses inherit the result.
    class_attribute :partial_field_types, instance_accessor: false,
                                          default: VIEWS.index_with(superclass.field_type).freeze
  end

  class_methods do
    def custom_partials(*names, **borrowed)
      types = names.index_with(field_type).merge(borrowed.transform_values(&:field_type)).stringify_keys
      types.assert_valid_keys(*VIEWS)
      self.partial_field_types = partial_field_types.merge(types).freeze
    end
  end

  def to_partial_path(name)
    "/madmin/fields/#{self.class.partial_field_types.fetch(name.to_s)}/#{name}"
  end
end

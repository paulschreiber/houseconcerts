# A read-only field whose value comes from a `compute:` lambda instead of a
# real column/association, e.g. `attribute :show_name, field: ComputedField,
# form: false, show: false, index: true, compute: ->(record) { record.show.name }`.
# With `link: true`, the index links it to the record, like LinkedStringField.
class ComputedField < Madmin::Fields::String
  def value(record)
    options.compute.call(record)
  end

  # Renders like a string field.
  def to_partial_path(name)
    return "/madmin/fields/linked_string_field/index" if name.to_s == "index" && options.link

    "/madmin/fields/string/#{name}"
  end
end

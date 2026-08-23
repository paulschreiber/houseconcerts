# A read-only field whose value comes from a `compute:` lambda instead of a
# real column/association, e.g. `attribute :show_name, field: ComputedField,
# form: false, show: false, index: true, compute: ->(record) { record.show.name }`
class ComputedField < Madmin::Fields::String
  def value(record)
    options.compute.call(record)
  end
end

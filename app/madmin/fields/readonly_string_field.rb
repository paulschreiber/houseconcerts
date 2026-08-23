# A string field that renders normally on index/show, but as plain text
# (not an input) on the new/edit form.
class ReadonlyStringField < Madmin::Fields::String
  def to_partial_path(name)
    return super if name.to_s == "form"

    "/madmin/fields/string/#{name}"
  end
end

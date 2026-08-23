class LinkedStringField < Madmin::Fields::String
  # Only the index view gets a custom partial (a link to the record); show
  # and form still render like a plain string field.
  def to_partial_path(name)
    return super if name.to_s == "index"

    "/madmin/fields/string/#{name}"
  end
end

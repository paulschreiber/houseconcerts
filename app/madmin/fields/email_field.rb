# A string field whose show page renders the address as a mailto: link.
class EmailField < Madmin::Fields::String
  def to_partial_path(name)
    return super if name.to_s == "show"

    "/madmin/fields/string/#{name}"
  end
end

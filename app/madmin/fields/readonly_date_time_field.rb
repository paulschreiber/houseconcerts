# A date_time field that renders normally on index/show, but as plain text
# (not a picker) on the new/edit form.
class ReadonlyDateTimeField < Madmin::Fields::DateTime
  def to_partial_path(name)
    return super if name.to_s == "form"

    "/madmin/fields/date_time/#{name}"
  end
end

# removed_at renders normally on show, and as plain text (not a picker) on
# the new/edit form.
class RemovedAtField < ShortDateTimeField
  def to_partial_path(name)
    return "/madmin/fields/readonly_date_time_field/form" if name.to_s == "form"

    super
  end
end

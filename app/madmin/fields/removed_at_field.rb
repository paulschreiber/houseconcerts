# removed_at renders normally on show, as plain text (not a picker) on the
# new/edit form, and only as an index column on the People "removed" scope
# (set via Current.admin_scope in Madmin::PeopleController).
class RemovedAtField < ShortDateTimeField
  def to_partial_path(name)
    return "/madmin/fields/readonly_date_time_field/form" if name.to_s == "form"

    super
  end

  def visible?(action)
    return false if action.to_sym == :index && Current.admin_scope != "removed"

    super
  end
end

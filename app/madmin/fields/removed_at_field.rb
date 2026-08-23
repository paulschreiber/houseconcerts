# removed_at renders normally on show, as plain text (not a picker) on the
# new/edit form, and only as an index column on the People "removed" scope
# (set via Current.admin_scope in Madmin::PeopleController).
class RemovedAtField < Madmin::Fields::DateTime
  def to_partial_path(name)
    case name.to_s
    when "form" then "/madmin/fields/readonly_date_time_field/form"
    when "index" then super
    else "/madmin/fields/date_time/#{name}"
    end
  end

  def visible?(action)
    return false if action.to_sym == :index && Current.admin_scope != "removed"

    super
  end
end

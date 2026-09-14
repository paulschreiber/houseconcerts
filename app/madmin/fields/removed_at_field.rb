# removed_at renders normally on show, as plain text (not a picker) on the
# new/edit form, and only as an index column on the People "removed" scope
# (set via Current.admin_scope in Madmin::PeopleController).
class RemovedAtField < ShortDateTimeField
  include HideableOnScope

  delegate_partial "form", to: "readonly_date_time_field"

  def hidden_on_index?
    Current.admin_scope != "removed"
  end
end

# attended_before is hidden as an index column on the RSVPs "all" (no
# scope), "previous_show", and "previous_show_attendees" scopes, since
# past-attendance history isn't useful context there.
class HideableAttendedBeforeField < ComputedField
  def visible?(action)
    return false if action.to_sym == :index && [ nil, "previous_show", "previous_show_attendees" ].include?(Current.admin_scope)

    super
  end

  # to_partial_path resolves from self.class, which is this subclass, not
  # ComputedField -- without this override the index partial path is
  # "hideable_attended_before_field/index", which doesn't exist.
  def to_partial_path(name)
    return "/madmin/fields/computed_field/index" if name.to_s == "index"

    super
  end
end

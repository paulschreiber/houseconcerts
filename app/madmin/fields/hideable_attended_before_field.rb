# attended_before is hidden as an index column on the RSVPs "all" (no
# scope), "previous_show", and "previous_show_attendees" scopes, since
# past-attendance history isn't useful context there.
class HideableAttendedBeforeField < ComputedField
  include HideableOnScope

  delegate_partial "index", to: "computed_field"

  def hidden_on_index?
    [ nil, "previous_show", "previous_show_attendees" ].include?(Current.admin_scope)
  end
end

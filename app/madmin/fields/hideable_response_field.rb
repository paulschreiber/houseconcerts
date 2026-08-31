# response is hidden as an index column on the RSVPs "next_show_attendees"
# scope (set via Current.admin_scope in Madmin::RsvpsController), since
# that scope only ever includes "yes" responses.
class HideableResponseField < RadioEnumField
  def visible?(action)
    return false if action.to_sym == :index && %w[next_show_attendees previous_show_attendees unconfirmed_rsvps].include?(Current.admin_scope)

    super
  end

  # RadioEnumField#to_partial_path only special-cases index/show (delegating
  # to the shared "enum" field views) and calls super for "form" -- but
  # super resolves the path from self.class, which is this subclass, not
  # RadioEnumField. Without this override, the form partial path is
  # "hideable_response_field/form", which doesn't exist.
  def to_partial_path(name)
    return "/madmin/fields/radio_enum_field/form" if name.to_s == "form"

    super
  end
end

# response is hidden as an index column on the RSVPs "next_show_attendees"
# scope (set via Current.admin_scope in Madmin::RsvpsController), since
# that scope only ever includes "yes" responses.
class HideableResponseField < RadioEnumField
  def visible?(action)
    return false if action.to_sym == :index && %w[next_show_attendees previous_show_attendees unconfirmed_rsvps].include?(Current.admin_scope)

    super
  end
end

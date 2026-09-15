# response is hidden as an index column on the RSVPs "next_show_attendees"
# scope (set via Current.admin_scope in Madmin::RsvpsController), since
# that scope only ever includes "yes" responses.
class HideableResponseField < RadioEnumField
  include HideableOnScope

  delegate_partial "form", to: "radio_enum_field"

  def hidden_on_index?
    [ "next_show_attendees", "previous_show_attendees", RSVP::UNCONFIRMED_RSVPS_SCOPE ].include?(Current.admin_scope)
  end
end

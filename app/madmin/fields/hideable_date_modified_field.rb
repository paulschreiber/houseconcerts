# updated_at is shown as an index column ("Date Modified") only on the RSVPs
# "next_show_attendees" scope, to spot recent changes before the show.
class HideableDateModifiedField < ShortDateTimeField
  include HideableOnScope

  def hidden_on_index?
    Current.admin_scope != "next_show_attendees"
  end
end

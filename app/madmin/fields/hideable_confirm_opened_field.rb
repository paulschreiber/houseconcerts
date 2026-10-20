# confirm_opened is shown as an index column only on the RSVPs attendee
# scopes, since only confirmed RSVPs get a confirmation email.
class HideableConfirmOpenedField < ComputedField
  include HideableOnScope

  def hidden_on_index?
    Madmin::RsvpsController::ATTENDEE_SCOPES.exclude?(Current.admin_scope)
  end
end

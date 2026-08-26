# ActiveSupport::Inflector's documented way to customize String#humanize
# output (inflect.human "unconfirmed_rsvps", "Unconfirmed RSVPs" in
# config/initializers/inflections.rb) doesn't take effect in this
# environment -- the rule is registered correctly but silently never
# applied. Registering "RSVPs" as an acronym instead isn't safe either,
# since that also feeds Zeitwerk's file->constant inflection and breaks
# autoloading for RsvpsController/RsvpsHelper. Patch String#humanize
# directly instead, scoped to this one exact string (used for Madmin's
# RSVP "unconfirmed_rsvps" scope button label) so nothing else is affected.
class String
  alias default_humanize humanize

  def humanize(...)
    return "Unconfirmed RSVPs" if self == "unconfirmed_rsvps"

    default_humanize(...)
  end
end

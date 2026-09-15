# Only Madmin's scope-button label (rendered via plain String#humanize in
# the gem's app/views/madmin/application/index.html.erb, which this app
# can't hook into without duplicating that whole view) needs this. Patching
# String#humanize globally is broader than that one call site, but the two
# narrower options don't work:
#
# - inflect.human "unconfirmed_rsvps", "Unconfirmed RSVPs" (the documented
#   way to customize #humanize, in config/initializers/inflections.rb)
#   gets applied, but #humanize's acronym pass then runs over the *result*
#   and re-lowercases any word not in the acronym table -- "RSVPs" isn't
#   registered (only "RSVP" is), so it comes back out as "Unconfirmed
#   rsvps" anyway. Verified with `ActiveSupport::Inflector.humanize`.
# - Registering "RSVPs" itself as an acronym does fix #humanize, but it
#   also feeds Zeitwerk's file->constant inflection and renames the
#   expected autoload constants to RSVPsController/RSVPsHelper. Verified
#   via Rails.autoloaders.main.inflector.camelize.
#
# So: patch String#humanize directly, scoped to this one exact string.
class String
  alias default_humanize humanize

  def humanize(...)
    return "Unconfirmed RSVPs" if self == RSVP::UNCONFIRMED_RSVPS_SCOPE

    default_humanize(...)
  end
end

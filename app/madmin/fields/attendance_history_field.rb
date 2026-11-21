# A person's attendance history (Person#rsvp_history): the shows they
# attended and the RSVPs they cancelled. Read-only, so it only has a show view.
class AttendanceHistoryField < ComputedField
  custom_partials :show
end

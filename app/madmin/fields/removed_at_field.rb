# removed_at renders normally on show, and as plain text (not a picker) on
# the new/edit form.
class RemovedAtField < ShortDateTimeField
  custom_partials form: ReadonlyDateTimeField
end

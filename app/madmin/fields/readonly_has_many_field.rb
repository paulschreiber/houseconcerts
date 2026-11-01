# A has_many field that renders normally on show, but as a plain read-only
# list (no attach/detach select) on the new/edit form.
class ReadonlyHasManyField < Madmin::Fields::HasMany
  include CustomPartials

  custom_partials :form
end

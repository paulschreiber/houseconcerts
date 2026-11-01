# A date_time field that renders normally on index/show, but as plain text
# (not a picker) on the new/edit form.
class ReadonlyDateTimeField < Madmin::Fields::DateTime
  include CustomPartials

  custom_partials :form
end

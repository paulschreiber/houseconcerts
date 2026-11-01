# A string field that renders normally on index/show, but as plain text
# (not an input) on the new/edit form.
class ReadonlyStringField < Madmin::Fields::String
  include CustomPartials

  custom_partials :form
end

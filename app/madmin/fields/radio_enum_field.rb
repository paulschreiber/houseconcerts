# An enum field that renders normally on index/show, but as radio buttons
# (a segmented control) instead of a <select> on the new/edit form.
class RadioEnumField < Madmin::Fields::Enum
  include CustomPartials

  custom_partials :form
end

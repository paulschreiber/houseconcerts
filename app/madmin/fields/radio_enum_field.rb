# An enum field that renders normally on index/show, but as radio buttons
# (a segmented control) instead of a <select> on the new/edit form.
class RadioEnumField < Madmin::Fields::Enum
  def to_partial_path(name)
    return super if name.to_s == "form"

    "/madmin/fields/enum/#{name}"
  end
end

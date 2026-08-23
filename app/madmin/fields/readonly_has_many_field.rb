# A has_many field that renders normally on show, but as a plain read-only
# list (no attach/detach select) on the new/edit form.
class ReadonlyHasManyField < Madmin::Fields::HasMany
  def to_partial_path(name)
    return super if name.to_s == "form"

    "/madmin/fields/has_many/#{name}"
  end
end

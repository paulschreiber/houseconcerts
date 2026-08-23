# A text field that preserves newlines (via simple_format) on the show page,
# instead of collapsing them into a single line like plain text output does.
class MultilineTextField < Madmin::Fields::Text
  def to_partial_path(name)
    return super if name.to_s == "show"

    "/madmin/fields/text/#{name}"
  end
end

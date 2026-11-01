# A text field that preserves newlines (via simple_format) on the show page,
# instead of collapsing them into a single line like plain text output does.
class MultilineTextField < Madmin::Fields::Text
  include CustomPartials

  custom_partials :show
end

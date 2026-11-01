# A string field whose show page renders the address as a mailto: link.
class EmailField < Madmin::Fields::String
  include CustomPartials

  custom_partials :show
end

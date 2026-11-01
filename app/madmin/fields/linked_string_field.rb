# A string field whose index renders the value as a link to the record.
class LinkedStringField < Madmin::Fields::String
  include CustomPartials

  custom_partials :index
end

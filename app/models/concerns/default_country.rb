# The site's country, read when a record is validated rather than when the
# model loads. The postal code and phone validators take it as
# `country: :default_country`, which has to be a public method on the record.
module DefaultCountry
  delegate :default_country, to: :Settings
end

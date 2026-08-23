# A date_time field whose index-table value omits seconds and the timezone
# offset (e.g. "2026-08-22 13:45" instead of "2026-08-22 13:45:07 -0400").
class ShortDateTimeField < Madmin::Fields::DateTime
  def to_partial_path(name)
    return "/madmin/fields/short_date_time_field/index" if name.to_s == "index"

    "/madmin/fields/date_time/#{name}"
  end
end

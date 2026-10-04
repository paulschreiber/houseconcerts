# A date_time field whose index-table value omits seconds and the timezone
# offset (e.g. "2026-08-22 13:45" instead of "2026-08-22 13:45:07 -0400").
# Options:
# - format: a strftime format for the index value instead (e.g. "%Y-%m-%d"
#   for just the date)
# - index_label: a label for the index's column header only. Madmin uses the
#   same label for the index and the show page, so the controller sets
#   Current.admin_action to tell them apart.
class ShortDateTimeField < Madmin::Fields::DateTime
  DEFAULT_FORMAT = "%Y-%m-%d %H:%M".freeze

  def to_partial_path(name)
    return "/madmin/fields/short_date_time_field/index" if name.to_s == "index"

    "/madmin/fields/date_time/#{name}"
  end

  def index_format = options[:format] || DEFAULT_FORMAT

  def label
    return options[:index_label] if Current.admin_action == "index" && options[:index_label].present?

    super
  end
end

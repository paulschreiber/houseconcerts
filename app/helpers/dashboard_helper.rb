module DashboardHelper
  BADGE_MODIFIERS = { "available" => "green", "waitlisted" => "amber", "sold_out" => "red", "cancelled" => "red" }.freeze

  # "Oct 2", with the year if it isn't this year.
  def dashboard_date(time)
    return if time.nil?

    time.strftime(time.year == Time.zone.today.year ? "%b %-d" : "%b %-d, %Y")
  end

  # "All 33 RSVPs", or just "1 RSVP" -- "All" reads oddly for one.
  def all_count_label(count, noun)
    label = pluralize(count, noun)
    count == 1 ? label : "All #{label}"
  end

  def days_until(show)
    days = (show.start.to_date - Time.zone.today).to_i
    case days
    when 0 then "today"
    when 1 then "tomorrow"
    else "in #{pluralize(days, 'day')}"
    end
  end

  def show_badge(value)
    modifier = BADGE_MODIFIERS[value]
    tag.span(value.humanize, class: [ "badge", ("badge--#{modifier}" if modifier) ])
  end

  # e.g. "Delia & the Lanterns invite", from the tag "<show slug>:invite".
  # The show name comes with its initials ("DL"), which phones show instead
  # (see madmin_custom.scss).
  def open_message(open, shows_by_slug)
    slug, email_type = open.tag.to_s.split(":", 2)
    show = shows_by_slug[slug]
    name = show ? show_name_with_initials(show.name) : slug
    safe_join([ name, email_type ].compact_blank, " ")
  end

  # The initials are the name's capitalized words (and numbers), so
  # "Delia & the Lanterns" is "DL", or every word's if none are capitalized
  # ("the lumineers" is "tl").
  def show_name_with_initials(name)
    initials = name.scan(/\b[[:upper:][:digit:]]/).join.presence || name.scan(/\b[[:alnum:]]/).join
    tag.span(name, class: "show-name") + tag.abbr(initials, title: name, class: "show-initials")
  end
end

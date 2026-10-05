module DashboardHelper
  GRAPH_WIDTH = 1100
  GRAPH_HEIGHT = 200
  GRAPH_PADDING = { top: 12, right: 40, bottom: 32, left: 40 }.freeze
  PAST_SHOW_COLORS = %w[#94a3b8 #a78bfa #f59e0b].freeze
  NEXT_SHOW_COLOR = "#2563eb".freeze
  TODAY_LABEL_WIDTH = 160

  BADGE_MODIFIERS = { "available" => "green", "waitlisted" => "amber", "sold_out" => "red", "cancelled" => "red" }.freeze

  # "2 hours ago" within the last day, then "yesterday", then "Oct 2" (with
  # the year if it isn't this year).
  def dashboard_time(time)
    return if time.nil?
    return "#{time_ago_in_words(time)} ago" if time > 1.day.ago
    return "yesterday" if time.to_date == Time.zone.yesterday

    time.strftime(time.year == Time.zone.today.year ? "%b %-d" : "%b %-d, %Y")
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
  def open_message(open, shows_by_slug)
    slug, email_type = open.tag.to_s.split(":", 2)
    [ shows_by_slug[slug]&.name || slug, email_type ].compact_blank.join(" ")
  end

  def graph_color(series, index)
    series.next_show ? NEXT_SHOW_COLOR : PAST_SHOW_COLORS[index % PAST_SHOW_COLORS.size]
  end

  def graph_label(series)
    label = "#{series.show.start.strftime('%b %-d')} · #{series.show.name}"
    series.next_show ? "#{label} (next)" : label
  end

  # Maps days before a show and seat counts to SVG coordinates: days run from
  # the most before (left) to show day (right).
  GraphScale = Data.define(:days, :seats) do
    def x(days_before) = scale(days - days_before, days, GRAPH_PADDING[:left], GRAPH_WIDTH - GRAPH_PADDING[:right])
    def y(count) = scale(seats - count, seats, GRAPH_PADDING[:top], GRAPH_HEIGHT - GRAPH_PADDING[:bottom])

    private

      def scale(value, range, low, high) = (low + ((high - low) * value / range.to_f)).round(1)
  end

  # Cumulative seats per day for each series, from its first yes RSVP to show
  # day.
  def rsvp_graph(all_series)
    days = round_up([ all_series.map { |series| series.points.first.first }.max, 7 ].max, 7)
    seats = round_up([ all_series.map { |series| series.points.last.last }.max, 10 ].max, 10)
    graph = GraphScale.new(days:, seats:)

    tag.svg(viewBox: "0 0 #{GRAPH_WIDTH} #{GRAPH_HEIGHT}", role: "img", aria: { label: "Seats reserved over time" }) do
      safe_join(graph_grid(graph) + graph_lines(all_series, graph))
    end
  end

  private

    def graph_grid(graph)
      seat_step = graph.seats > 100 ? 20 : 10
      day_step = graph.days > 70 ? 14 : 7
      rows = (0..graph.seats).step(seat_step).flat_map do |count|
        [ tag.line(x1: GRAPH_PADDING[:left], x2: GRAPH_WIDTH - GRAPH_PADDING[:right], y1: graph.y(count), y2: graph.y(count), class: "grid"),
          tag.text(count, x: GRAPH_PADDING[:left] - 6, y: graph.y(count) + 4, "text-anchor": "end") ]
      end
      columns = (0..graph.days).step(day_step).map do |days_before|
        tag.text(days_before.zero? ? "Show day" : "#{days_before} days before",
                 x: graph.x(days_before), y: GRAPH_HEIGHT - 10, "text-anchor": axis_label_anchor(days_before, graph))
      end
      rows + columns
    end

    def graph_lines(all_series, graph)
      all_series.each_with_index.flat_map do |series, index|
        color = graph_color(series, index)
        path = series.points.map.with_index { |(days_before, count), i| "#{i.zero? ? 'M' : 'L'}#{graph.x(days_before)},#{graph.y(count)}" }.join(" ")
        line = tag.path(d: path, fill: "none", stroke: color, "stroke-width": series.next_show ? 3 : 2, "stroke-linejoin": "round")
        next [ line ] unless series.next_show

        days_before, count = series.points.last
        [ line, tag.circle(cx: graph.x(days_before), cy: graph.y(count), r: 4, fill: color), today_label(graph, days_before, count) ]
      end
    end

    # Above the point, and to its left near show day so it stays inside the
    # graph.
    def today_label(graph, days_before, count)
      x = graph.x(days_before)
      near_end = x > GRAPH_WIDTH - TODAY_LABEL_WIDTH
      tag.text("Today: #{pluralize(count, 'seat')}", x: near_end ? x - 6 : x + 6, y: graph.y(count) - 10,
                                                     "text-anchor": near_end ? "end" : "start", class: "today")
    end

    # The end labels sit inside the graph instead of centered on their tick.
    def axis_label_anchor(days_before, graph)
      return "end" if days_before.zero?
      return "start" if days_before == graph.days

      "middle"
    end

    def round_up(value, step) = (value.to_f / step).ceil * step
end

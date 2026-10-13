# The dashboard's seats reserved over time graph, with its legend's colors
# and labels.
module DashboardGraphHelper
  # The graph's size and margins in SVG units, how wide a today label is,
  # and whether the x-axis labels are just the number of days. The SVG scales
  # to the page's width, so phones get a narrower graph whose text (sized in
  # madmin_custom.scss) scales down less.
  GraphLayout = Data.define(:width, :height, :padding, :today_label_width, :short_axis_labels)
  GRAPH_LAYOUTS = {
    desktop: GraphLayout.new(width: 1100, height: 200, padding: { top: 12, right: 40, bottom: 32, left: 40 }, today_label_width: 160,
                             short_axis_labels: false),
    phone: GraphLayout.new(width: 400, height: 220, padding: { top: 18, right: 12, bottom: 30, left: 30 }, today_label_width: 130,
                           short_axis_labels: true)
  }.freeze
  PAST_SHOW_COLORS = %w[#94a3b8 #a78bfa #f59e0b].freeze
  UPCOMING_SHOW_COLORS = { next: "#2563eb", following: "#0d9488" }.freeze

  def graph_color(series, index)
    UPCOMING_SHOW_COLORS.fetch(series.role) { PAST_SHOW_COLORS[index % PAST_SHOW_COLORS.size] }
  end

  def graph_label(series)
    "#{series.show.start.strftime('%b %-d')} · #{series.show.name}"
  end

  # Maps days before a show and seat counts to SVG coordinates: days run from
  # the most before (left) to show day (right).
  GraphScale = Data.define(:days, :seats, :layout) do
    def x(days_before) = scale(days - days_before, days, layout.padding[:left], layout.width - layout.padding[:right])
    def y(count) = scale(seats - count, seats, layout.padding[:top], layout.height - layout.padding[:bottom])

    private

      def scale(value, range, low, high) = (low + ((high - low) * value / range.to_f)).round(1)
  end

  # Cumulative seats per day for each series, over the last
  # Dashboard::GRAPH_DAYS before show day: one graph for wider screens and one
  # for phones (madmin_custom.scss shows one or the other).
  def rsvp_graph(all_series)
    seats = round_up([ all_series.map { |series| series.points.last.last }.max, 10 ].max, 10)
    safe_join(GRAPH_LAYOUTS.map do |name, layout|
      graph = GraphScale.new(days: Dashboard::GRAPH_DAYS, seats:, layout:)
      tag.svg(viewBox: "0 0 #{layout.width} #{layout.height}", role: "img", aria: { label: "Seats reserved over time" }, class: "graph-#{name}") do
        safe_join(graph_grid(graph) + graph_lines(all_series, graph))
      end
    end)
  end

  private

    def graph_grid(graph)
      layout = graph.layout
      seat_step = graph.seats > 100 ? 20 : 10
      rows = (0..graph.seats).step(seat_step).flat_map do |count|
        [ tag.line(x1: layout.padding[:left], x2: layout.width - layout.padding[:right], y1: graph.y(count), y2: graph.y(count), class: "grid"),
          tag.text(count, x: layout.padding[:left] - 6, y: graph.y(count) + 4, "text-anchor": "end") ]
      end
      columns = (0..graph.days).step(7).map do |days_before|
        tag.text(axis_label(days_before, graph), x: graph.x(days_before), y: layout.height - 10, "text-anchor": axis_label_anchor(days_before, graph))
      end
      rows + columns
    end

    def axis_label(days_before, graph)
      return days_before if graph.layout.short_axis_labels

      days_before.zero? ? "Show day" : "#{days_before} days before"
    end

    # Upcoming shows' lines end in a dot at today. Only the first one drawn
    # (the next show's, unless it has no RSVPs yet) gets a today label, so two
    # labels can't overlap.
    def graph_lines(all_series, graph)
      labeled = all_series.find(&:upcoming?)
      all_series.each_with_index.flat_map do |series, index|
        color = graph_color(series, index)
        path = series.points.map.with_index { |(days_before, count), i| "#{i.zero? ? 'M' : 'L'}#{graph.x(days_before)},#{graph.y(count)}" }.join(" ")
        line = tag.path(d: path, fill: "none", stroke: color, "stroke-width": series.upcoming? ? 3 : 2, "stroke-linejoin": "round")
        next [ line ] unless series.upcoming?

        days_before, count = series.points.last
        today = tag.circle(cx: graph.x(days_before), cy: graph.y(count), r: 4, fill: color)
        [ line, today, (today_label(graph, days_before, count) if series == labeled) ].compact
      end
    end

    # Above the point (below it when that would reach the graph's top edge),
    # and to its left near show day, so it stays inside the graph.
    def today_label(graph, days_before, count)
      x = graph.x(days_before)
      y = graph.y(count) - 10
      y = graph.y(count) + 20 if y < graph.layout.padding[:top]
      near_end = x > graph.layout.width - graph.layout.today_label_width
      tag.text("Today: #{pluralize(count, 'seat')}", x: near_end ? x - 6 : x + 6, y:,
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

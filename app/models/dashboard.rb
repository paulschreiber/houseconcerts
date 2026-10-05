# What the admin dashboard shows: the next show's RSVPs, upcoming shows, the
# previous show's follow-up work, recent opens and unsubscribes, and seats
# reserved over time for recent shows.
class Dashboard
  RECENT_LIMIT = 5
  GRAPHED_PAST_SHOWS = 3

  # One graph line: cumulative yes seats per day, as [days before the show,
  # seats] pairs from the show's first yes RSVP to show day (or today, for the
  # next show, which next_show marks).
  Series = Data.define(:show, :points, :next_show)

  def next_show
    return @next_show if defined?(@next_show)

    @next_show = Show.next
  end

  def previous_show
    return @previous_show if defined?(@previous_show)

    @previous_show = Show.previous
  end

  # Seats of yes RSVPs, keyed by confirmation status (waitlisted seats
  # included, under "waitlisted").
  def next_show_seats
    @next_show_seats ||= RSVP.where(show: next_show).yes.group(:confirmed).sum(:seats_reserved)
  end

  # RSVP counts keyed by response.
  def next_show_responses
    @next_show_responses ||= RSVP.where(show: next_show).group(:response).count
  end

  def recent_rsvps
    RSVP.where(show: next_show).order(created_at: :desc).limit(RECENT_LIMIT)
  end

  # The next show's unconfirmed and waitlisted yes RSVPs, oldest first.
  def unconfirmed_rsvps
    RSVP.unconfirmed_rsvps.includes(:show).order(:created_at)
  end

  # Shows that haven't happened yet, including unconfirmed ones.
  def upcoming_shows
    Show.where("start > ?", Time.zone.now).where.not(status: "cancelled").order(:start)
  end

  # Seats reserved, keyed by show id.
  def seats_by_show(shows)
    reserved(RSVP.where(show: shows)).group(:show_id).sum(:seats_reserved)
  end

  def recent_opens
    Open.order(created_at: :desc).limit(RECENT_LIMIT)
  end

  # The shows that recent opens' tags name ("<show slug>:<email type>"),
  # keyed by slug.
  def shows_by_slug(opens)
    slugs = opens.map { |open| open.tag.to_s.split(":").first }
    Show.where(slug: slugs).index_by(&:slug)
  end

  def recent_unsubscribes
    Person.removed.order(removed_at: :desc).limit(RECENT_LIMIT)
  end

  def previous_show_attendees
    previous_show&.attendees || RSVP.none
  end

  def attendance_recorded?
    previous_show_attendees.exists? && !previous_show_attendees.exists?(seats_used: nil)
  end

  def nonsubscribers_to_add
    AddNonsubscribers.addable(previous_show).count
  end

  def phone_numbers_to_add
    previous_show ? AddPhoneNumbers.new(previous_show).people.count : 0
  end

  # The last few shows, then the next one.
  def graph_series
    shows = Show.past.last(GRAPHED_PAST_SHOWS)
    shows << next_show if next_show
    shows.filter_map do |show|
      points = seats_over_time(show)
      Series.new(show:, points:, next_show: show == next_show) if points.any?
    end
  end

  private

    # Yes RSVPs holding seats: confirmed or unconfirmed, not waitlisted.
    def reserved(rsvps)
      rsvps.yes.where.not(confirmed: "waitlisted")
    end

    def seats_over_time(show)
      show_day = show.start.to_date
      seats_by_day = Hash.new(0)
      reserved(RSVP.where(show:)).pluck(:created_at, :seats_reserved).each do |created_at, seats|
        seats_by_day[[ (show_day - created_at.to_date).to_i, 0 ].max] += seats.to_i
      end
      return [] if seats_by_day.empty?

      last_day = [ (show_day - Time.zone.today).to_i, 0 ].max
      total = 0
      seats_by_day.keys.max.downto(last_day).map do |days_before|
        total += seats_by_day[days_before]
        [ days_before, total ]
      end
    end
end

# What the admin dashboard shows: the next show's invites and RSVPs, upcoming
# shows, the previous show's follow-up work, recent opens and unsubscribes,
# and seats reserved over time for recent and upcoming shows.
class Dashboard
  RECENT_LIMIT = 5
  GRAPHED_PAST_SHOWS = 3
  GRAPH_DAYS = 49

  # One graph line: cumulative yes seats per day, as [days before the show,
  # seats] pairs from the show's first yes RSVP (or GRAPH_DAYS before the show,
  # if later) to show day (or today, for an upcoming show). role is :past,
  # :next or :following (the show after next).
  Series = Data.define(:show, :points, :role) do
    def upcoming?
      role != :past
    end
  end

  def next_show
    next_two_shows.first
  end

  def previous_show
    graphed_past_shows.last
  end

  # Seats of yes RSVPs, keyed by confirmation status (waitlisted seats
  # included, under "waitlisted").
  def next_show_seats
    @next_show_seats ||= next_show_rsvps.yes.group(:confirmed).sum(:seats_reserved)
  end

  # People an invite batch sent the next show's invite to, counting each
  # once. Single invites (InvitePerson) aren't recorded, so aren't counted.
  def invites_sent
    @invites_sent ||= invited_people.distinct.count(:recipient_id)
  end

  # Of the people invites_sent counts, those who opened an invite.
  def invites_opened
    invited_emails = Person.where(id: invited_people.select(:recipient_id)).select(:email)
    Open.invites_to(next_show).where(email: invited_emails).distinct.count(:email)
  end

  # People who can be invited to the next show but haven't been sent an invite.
  def not_yet_invited
    Person.invitable_for(next_show).where.not(id: invited_people.select(:recipient_id)).count
  end

  # RSVP counts keyed by response.
  def next_show_responses
    @next_show_responses ||= next_show_rsvps.group(:response).count
  end

  def recent_rsvps
    next_show_rsvps.order(responded_at: :desc).limit(RECENT_LIMIT)
  end

  # The next show's unconfirmed and waitlisted yes RSVPs, oldest first.
  def unconfirmed_rsvps
    next_show_rsvps.awaiting_confirmation.includes(:show).order(:created_at)
  end

  # Shows that haven't happened yet, including unconfirmed ones.
  def upcoming_shows
    Show.where("start > ?", Time.zone.now).where.not(status: "cancelled").order(:start)
  end

  # Seats reserved, keyed by show id.
  def seats_by_show(shows)
    RSVP.where(show: shows).holding_seats.group(:show_id).sum(:seats_reserved)
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

  # Who each open's email belongs to, keyed by email: their Person, or for
  # someone not on the mailing list, their latest RSVP.
  def openers_by_email(opens)
    emails = opens.filter_map(&:email).uniq
    openers = Person.where(email: emails).index_by(&:email)
    RSVP.where(email: emails - openers.keys).order(:id).index_by(&:email).merge(openers)
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

  # The last few shows, then the next one and the one after it, leaving out
  # shows without yes RSVPs and shows more than GRAPH_DAYS away.
  def graph_series
    roles = graphed_past_shows.index_with(:past)
                              .merge(next_two_shows.zip(%i[next following]).to_h)
    roles.filter_map do |show, role|
      points = seats_over_time(show)
      Series.new(show:, points:, role:) if points.any?
    end
  end

  private

    def next_two_shows
      @next_two_shows ||= Show.upcoming.first(2)
    end

    def graphed_past_shows
      @graphed_past_shows ||= Show.past.last(GRAPHED_PAST_SHOWS)
    end

    def next_show_rsvps
      RSVP.where(show: next_show)
    end

    def invited_people
      BatchRunItem.sent.where(recipient_type: "Person").joins(:batch_run)
                  .where(batch_runs: { show_id: next_show, kind: %w[invite invite_unopened] })
    end

    # Seats reserved more than GRAPH_DAYS before the show count as reserved
    # on that day, where the line starts.
    def seats_over_time(show)
      show_day = show.start.to_date
      last_day = [ (show_day - Time.zone.today).to_i, 0 ].max
      return [] if last_day > GRAPH_DAYS

      seats_by_day = Hash.new(0)
      RSVP.where(show:).holding_seats.pluck(:created_at, :seats_reserved).each do |created_at, seats|
        seats_by_day[(show_day - created_at.to_date).to_i.clamp(0, GRAPH_DAYS)] += seats.to_i
      end
      return [] if seats_by_day.empty?

      total = 0
      seats_by_day.keys.max.downto(last_day).map do |days_before|
        total += seats_by_day[days_before]
        [ days_before, total ]
      end
    end
end

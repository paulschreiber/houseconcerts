class ShowsController < ApplicationController
  def index
    @shows = Show.upcoming.includes(:artists, :venue).to_a
    # The homepage's social media image is the next show's.
    @social_media_show = @shows.first
  end

  def shows
    @shows = Show.past.occurred.includes(:artists, :venue)
  end

  def calendar
    cal = Icalendar::Calendar.new
    shows = Show.upcoming.includes(:venue)
    shows.each do |show|
      cal.event do |e|
        e.dtstart     = Icalendar::Values::DateTime.new(show.start.utc, tzid: "UTC")
        e.dtend       = Icalendar::Values::DateTime.new(show.end.utc, tzid: "UTC")
        e.summary     = show.event_name
        e.location    = show.location
        e.url         = rsvp_for_show_url(slug: show.slug)
        e.uid         = "event-#{show.slug}@#{Settings.domain}"
      end
    end
    cal.publish
    render plain: cal.to_ical, content_type: "text/calendar"
  end
end

class ShowsController < ApplicationController
  def index
    @shows = Show.upcoming
  end

  def shows
    @shows = Show.past.occurred
  end

  def calendar
    cal = Icalendar::Calendar.new
    Show.upcoming.each do |show|
      cal.event do |e|
        e.dtstart     = Icalendar::Values::DateTime.new(show.start)
        e.dtend       = Icalendar::Values::DateTime.new(show.end)
        e.summary     = "#{show.name} House Concert"
        e.location    = show.location
        e.url         = rsvp_for_show_url(slug: show.slug)
        e.uid         = "event-#{show.slug}@#{Settings.domain}"
      end
    end
    cal.publish
    render plain: cal.to_ical, content_type: "text/calendar"
  end
end

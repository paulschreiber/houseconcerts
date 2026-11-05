class ShowsController < ApplicationController
  def index
    @shows = Show.upcoming.includes(:venue, artists: { photo_attachment: :blob }).to_a
    # The homepage's social media image is the next show's.
    @social_media_show = @shows.first
  end

  def shows
    @shows = Show.past.occurred.includes(:venue, artists: { photo_attachment: :blob })
  end

  def calendar
    events = Show.upcoming.includes(:venue).map { |show| show.ical_event(url: rsvp_for_show_url(slug: show.slug)) }
    render plain: Show.ical(events), content_type: "text/calendar"
  end
end
